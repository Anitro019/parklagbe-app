-- Keep exact Bangladesh-time listing boundaries queryable and enforce them for
-- every booking insert/update, including calls made outside the Flutter client.
ALTER TABLE public.parking_spots
    ADD COLUMN IF NOT EXISTS available_from TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS available_to TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION public.sync_parking_spot_availability_timestamps()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    NEW.available_from := CASE
        WHEN NEW.available_start_date IS NULL THEN NULL
        ELSE (NEW.available_start_date + NEW.available_hours_start) AT TIME ZONE 'Asia/Dhaka'
    END;
    NEW.available_to := CASE
        WHEN NEW.available_end_date IS NULL THEN NULL
        ELSE (NEW.available_end_date + NEW.available_hours_end) AT TIME ZONE 'Asia/Dhaka'
    END;
    RETURN NEW;
END;
$$;

UPDATE public.parking_spots
SET available_from = CASE
        WHEN available_start_date IS NULL THEN NULL
        ELSE (available_start_date + available_hours_start) AT TIME ZONE 'Asia/Dhaka'
    END,
    available_to = CASE
        WHEN available_end_date IS NULL THEN NULL
        ELSE (available_end_date + available_hours_end) AT TIME ZONE 'Asia/Dhaka'
    END;

DROP TRIGGER IF EXISTS sync_parking_spot_availability_timestamps
    ON public.parking_spots;
CREATE TRIGGER sync_parking_spot_availability_timestamps
    BEFORE INSERT OR UPDATE ON public.parking_spots
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_parking_spot_availability_timestamps();

CREATE INDEX IF NOT EXISTS idx_parking_spots_available_to
    ON public.parking_spots(available_to);

CREATE OR REPLACE FUNCTION public.enforce_booking_listing_availability()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_available_from TIMESTAMPTZ;
    v_available_to TIMESTAMPTZ;
BEGIN
    IF NEW.end_time <= NOW() THEN
        RAISE EXCEPTION 'Expired Availability: Booking end time must be in the future.';
    END IF;

    SELECT available_from, available_to
    INTO v_available_from, v_available_to
    FROM public.parking_spots
    WHERE id = NEW.spot_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Parking spot not found.';
    END IF;

    IF v_available_from IS NOT NULL AND NEW.start_time < v_available_from THEN
        RAISE EXCEPTION 'Outside Availability: Booking cannot start before the listing is available.';
    END IF;

    IF v_available_to IS NOT NULL AND NEW.end_time > v_available_to THEN
        RAISE EXCEPTION 'Expired Availability: Booking must end before the listing expires.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_booking_listing_availability
    ON public.bookings;
CREATE TRIGGER enforce_booking_listing_availability
    BEFORE INSERT OR UPDATE OF spot_id, start_time, end_time
    ON public.bookings
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_booking_listing_availability();

NOTIFY pgrst, 'reload schema';
