-- ==============================================================================
-- Migration: 20261024000004_create_booking_engine_functions.sql
-- Description: Dynamic operational hours, overlap checking, pessimistic locking & pricing
-- Note: Fully idempotent using DROP IF EXISTS so it can be re-run safely.
-- ==============================================================================

-- 1. HELPER: GENERATE UNIQUE BOOKING REFERENCE
CREATE OR REPLACE FUNCTION public.generate_booking_reference()
RETURNS TEXT AS $$
DECLARE
    ref TEXT;
    exists_count INT;
BEGIN
    LOOP
        ref := 'PKL-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
        SELECT COUNT(*) INTO exists_count FROM public.bookings WHERE booking_reference = ref;
        EXIT WHEN exists_count = 0;
    END LOOP;
    RETURN ref;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

-- 2. SERVER-SIDE CHECK: SPOT AVAILABILITY WITH DYNAMIC OPERATIONAL HOURS & OVERLAP
CREATE OR REPLACE FUNCTION public.check_spot_availability(
    p_spot_id UUID,
    p_start_time TIMESTAMPTZ,
    p_end_time TIMESTAMPTZ
)
RETURNS BOOLEAN AS $$
DECLARE
    v_spot record;
    v_closed_count INT;
    v_overlapping_count INT;
    v_start_time_local TIME;
    v_end_time_local TIME;
    v_day_code TEXT;
BEGIN
    -- Fetch spot
    SELECT * INTO v_spot
    FROM public.parking_spots
    WHERE id = p_spot_id;

    IF NOT FOUND OR NOT v_spot.is_active OR v_spot.approval_status <> 'approved' THEN
        RETURN FALSE;
    END IF;

    IF p_end_time <= p_start_time OR p_end_time <= NOW() THEN
        RETURN FALSE;
    END IF;

    IF v_spot.available_from IS NOT NULL AND p_start_time < v_spot.available_from THEN
        RETURN FALSE;
    END IF;

    IF v_spot.available_to IS NOT NULL AND p_end_time > v_spot.available_to THEN
        RETURN FALSE;
    END IF;

    -- Local Bangladesh Time conversions for operating hours comparison
    v_start_time_local := (p_start_time AT TIME ZONE 'Asia/Dhaka')::TIME;
    v_end_time_local := (p_end_time AT TIME ZONE 'Asia/Dhaka')::TIME;
    v_day_code := LOWER(TO_CHAR(p_start_time AT TIME ZONE 'Asia/Dhaka', 'Dy'));

    -- Check available days
    IF NOT (v_day_code = ANY(v_spot.available_days)) THEN
        RETURN FALSE;
    END IF;

    -- Check operational hours window
    IF v_start_time_local < v_spot.available_hours_start OR v_end_time_local > v_spot.available_hours_end THEN
        RETURN FALSE;
    END IF;

    -- Check if date is in closed dates
    SELECT COUNT(*) INTO v_closed_count
    FROM public.parking_closed_dates
    WHERE spot_id = p_spot_id AND closed_date = (p_start_time AT TIME ZONE 'UTC')::DATE;

    IF v_closed_count > 0 THEN
        RETURN FALSE;
    END IF;

    -- Count active overlapping bookings (Strict time overlap check: start < p_end AND end > p_start)
    -- Adjacent bookings (e.g. 10:00-12:00 and 12:00-17:00) do NOT overlap!
    SELECT COUNT(*) INTO v_overlapping_count
    FROM public.bookings
    WHERE spot_id = p_spot_id
      AND booking_status IN ('pending', 'confirmed', 'active')
      AND start_time < p_end_time
      AND end_time > p_start_time;

    RETURN v_overlapping_count < v_spot.capacity;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- 3. SERVER TRANSACTION: CREATE BOOKING WITH DYNAMIC OPERATIONAL HOURS, OVERLAP & PESSIMISTIC LOCKING
CREATE OR REPLACE FUNCTION public.create_booking(
    p_spot_id UUID,
    p_vehicle_type TEXT,
    p_vehicle_number TEXT,
    p_booking_date DATE,
    p_start_time TIMESTAMPTZ,
    p_end_time TIMESTAMPTZ,
    p_rental_type TEXT DEFAULT 'hourly'
)
RETURNS public.bookings AS $$
DECLARE
    v_spot record;
    v_customer_id UUID;
    v_overlapping_count INT;
    v_closed_count INT;
    v_duration_hours NUMERIC(10,2);
    v_rate NUMERIC(10,2);
    v_total_price NUMERIC(10,2);
    v_advance_amount NUMERIC(10,2);
    v_ref TEXT;
    v_new_booking public.bookings;
    v_breakdown JSONB;
    v_start_time_local TIME;
    v_end_time_local TIME;
    v_day_code TEXT;
BEGIN
    v_customer_id := auth.uid();
    IF v_customer_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User must be authenticated to create a booking.';
    END IF;

    IF p_end_time <= p_start_time THEN
        RAISE EXCEPTION 'Invalid Time Window: End time must be strictly after start time.';
    END IF;

    IF p_end_time <= NOW() THEN
        RAISE EXCEPTION 'Expired Availability: Booking end time must be in the future.';
    END IF;

    -- 1. Lock parking spot row to prevent race conditions (Pessimistic locking)
    SELECT * INTO v_spot
    FROM public.parking_spots
    WHERE id = p_spot_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Parking spot not found.';
    END IF;

    IF NOT v_spot.is_active OR v_spot.approval_status <> 'approved' THEN
        RAISE EXCEPTION 'Parking spot is currently unavailable for bookings.';
    END IF;

    IF v_spot.available_from IS NOT NULL AND p_start_time < v_spot.available_from THEN
        RAISE EXCEPTION 'Outside Availability: Booking cannot start before the listing is available.';
    END IF;

    IF v_spot.available_to IS NOT NULL AND p_end_time > v_spot.available_to THEN
        RAISE EXCEPTION 'Expired Availability: Booking must end before the listing expires.';
    END IF;

    -- 2. Validate operational days & hours
    v_start_time_local := (p_start_time AT TIME ZONE 'Asia/Dhaka')::TIME;
    v_end_time_local := (p_end_time AT TIME ZONE 'Asia/Dhaka')::TIME;
    v_day_code := LOWER(TO_CHAR(p_start_time AT TIME ZONE 'Asia/Dhaka', 'Dy'));

    IF NOT (v_day_code = ANY(v_spot.available_days)) THEN
        RAISE EXCEPTION 'Unavailable Day: Parking spot is not open on this day of the week.';
    END IF;

    IF v_start_time_local < v_spot.available_hours_start OR v_end_time_local > v_spot.available_hours_end THEN
        RAISE EXCEPTION 'Outside Operational Hours: Spot is only open from % to %.', v_spot.available_hours_start::TEXT, v_spot.available_hours_end::TEXT;
    END IF;

    -- 3. Check closed dates
    SELECT COUNT(*) INTO v_closed_count
    FROM public.parking_closed_dates
    WHERE spot_id = p_spot_id AND closed_date = p_booking_date;

    IF v_closed_count > 0 THEN
        RAISE EXCEPTION 'Parking spot is closed on the selected date.';
    END IF;

    -- 4. Check overlapping bookings against spot capacity
    -- Strict overlap check: start_time < p_end_time AND end_time > p_start_time
    SELECT COUNT(*) INTO v_overlapping_count
    FROM public.bookings
    WHERE spot_id = p_spot_id
      AND booking_status IN ('pending', 'confirmed', 'active')
      AND start_time < p_end_time
      AND end_time > p_start_time;

    IF v_overlapping_count >= v_spot.capacity THEN
        RAISE EXCEPTION 'Parking spot is fully booked for the selected time window.';
    END IF;

    -- 5. Calculate duration and server-side pricing
    v_duration_hours := ROUND((EXTRACT(EPOCH FROM (p_end_time - p_start_time)) / 3600.0)::NUMERIC, 2);

    IF v_duration_hours <= 0 THEN
        RAISE EXCEPTION 'Duration must be greater than zero hours.';
    END IF;

    IF p_rental_type = 'daily' THEN
        v_rate := COALESCE(v_spot.daily_price, v_spot.hourly_price * 24.0);
        v_total_price := CEIL(v_duration_hours / 24.0) * v_rate;
    ELSIF p_rental_type = 'monthly' THEN
        v_rate := COALESCE(v_spot.monthly_price, v_spot.daily_price * 30.0);
        v_total_price := CEIL(v_duration_hours / 720.0) * v_rate;
    ELSE
        -- Default: Hourly
        v_rate := COALESCE(v_spot.hourly_price, 50.00);
        v_total_price := v_duration_hours * v_rate;
    END IF;

    v_advance_amount := ROUND((v_total_price * (v_spot.advance_requirement_percentage / 100.0))::NUMERIC, 2);
    v_ref := public.generate_booking_reference();

    v_breakdown := jsonb_build_object(
        'hourly_rate', v_rate,
        'duration_hours', v_duration_hours,
        'subtotal', v_total_price,
        'advance_percentage', v_spot.advance_requirement_percentage,
        'advance_amount', v_advance_amount,
        'due_on_arrival', v_total_price - v_advance_amount
    );

    -- 6. Insert booking record
    INSERT INTO public.bookings (
        booking_reference,
        customer_id,
        spot_id,
        vehicle_type,
        vehicle_number,
        booking_date,
        start_time,
        end_time,
        duration_hours,
        rental_type,
        price_breakdown,
        total_price,
        advance_amount,
        booking_status
    )
    VALUES (
        v_ref,
        v_customer_id,
        p_spot_id,
        p_vehicle_type,
        p_vehicle_number,
        p_booking_date,
        p_start_time,
        p_end_time,
        v_duration_hours,
        p_rental_type,
        v_breakdown,
        v_total_price,
        v_advance_amount,
        'pending'
    )
    RETURNING * INTO v_new_booking;

    RETURN v_new_booking;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public;

-- 4. SERVER TRANSACTION: APPROVE BOOKING WITH RE-VERIFICATION
CREATE OR REPLACE FUNCTION public.approve_booking(p_booking_id UUID)
RETURNS public.bookings AS $$
DECLARE
    v_booking public.bookings;
    v_spot public.parking_spots;
    v_overlapping_count INT;
BEGIN
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found.';
    END IF;

    -- Verify caller is spot owner or admin
    SELECT * INTO v_spot FROM public.parking_spots WHERE id = v_booking.spot_id FOR UPDATE;
    IF v_spot.owner_id <> auth.uid() AND NOT public.is_admin(auth.uid()) THEN
        RAISE EXCEPTION 'Unauthorized: Only the parking spot owner can approve this booking.';
    END IF;

    -- Re-verify overlap count vs capacity
    SELECT COUNT(*) INTO v_overlapping_count
    FROM public.bookings
    WHERE spot_id = v_booking.spot_id
      AND id <> p_booking_id
      AND booking_status IN ('confirmed', 'active')
      AND start_time < v_booking.end_time
      AND end_time > v_booking.start_time;

    IF v_overlapping_count >= v_spot.capacity THEN
        RAISE EXCEPTION 'Cannot approve booking: Capacity exceeded due to confirmed overlapping bookings.';
    END IF;

    UPDATE public.bookings
    SET booking_status = 'confirmed', updated_at = NOW()
    WHERE id = p_booking_id
    RETURNING * INTO v_booking;

    RETURN v_booking;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public;

-- 5. SERVER TRANSACTION: CANCEL BOOKING
CREATE OR REPLACE FUNCTION public.cancel_booking(p_booking_id UUID)
RETURNS public.bookings AS $$
DECLARE
    v_booking public.bookings;
    v_spot public.parking_spots;
BEGIN
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found.';
    END IF;

    SELECT * INTO v_spot FROM public.parking_spots WHERE id = v_booking.spot_id;

    -- Verify caller is customer, spot owner, or admin
    IF v_booking.customer_id <> auth.uid() AND v_spot.owner_id <> auth.uid() AND NOT public.is_admin(auth.uid()) THEN
        RAISE EXCEPTION 'Unauthorized: You do not have permission to cancel this booking.';
    END IF;

    UPDATE public.bookings
    SET booking_status = 'cancelled', updated_at = NOW()
    WHERE id = p_booking_id
    RETURNING * INTO v_booking;

    RETURN v_booking;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public;

-- 6. SERVER TRANSACTION: REJECT BOOKING
CREATE OR REPLACE FUNCTION public.reject_booking(
    p_booking_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS public.bookings AS $$
DECLARE
    v_booking public.bookings;
    v_spot public.parking_spots;
BEGIN
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found.';
    END IF;

    SELECT * INTO v_spot FROM public.parking_spots WHERE id = v_booking.spot_id;

    -- Verify caller is spot owner or admin
    IF v_spot.owner_id <> auth.uid() AND NOT public.is_admin(auth.uid()) THEN
        RAISE EXCEPTION 'Unauthorized: Only the parking spot owner can reject this booking.';
    END IF;

    UPDATE public.bookings
    SET booking_status = 'rejected', updated_at = NOW()
    WHERE id = p_booking_id
    RETURNING * INTO v_booking;

    RETURN v_booking;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public;

-- 7. SERVER TRANSACTION: COMPLETE BOOKING
CREATE OR REPLACE FUNCTION public.complete_booking(p_booking_id UUID)
RETURNS public.bookings AS $$
DECLARE
    v_booking public.bookings;
    v_spot public.parking_spots;
BEGIN
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found.';
    END IF;

    SELECT * INTO v_spot FROM public.parking_spots WHERE id = v_booking.spot_id;

    -- Verify caller is spot owner or admin
    IF v_spot.owner_id <> auth.uid() AND NOT public.is_admin(auth.uid()) THEN
        RAISE EXCEPTION 'Unauthorized: Only the parking spot owner can mark this booking as completed.';
    END IF;

    IF v_booking.booking_status NOT IN ('confirmed', 'active') THEN
        RAISE EXCEPTION 'Invalid State: Only confirmed or active bookings can be marked as completed.';
    END IF;

    UPDATE public.bookings
    SET booking_status = 'completed', updated_at = NOW()
    WHERE id = p_booking_id
    RETURNING * INTO v_booking;

    RETURN v_booking;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public;
