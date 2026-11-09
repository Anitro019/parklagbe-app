-- ==============================================================================
-- Migration: 20261024000005_create_notifications_and_reviews_helpers.sql
-- Description: Automatic in-app notification triggers, review validation, and complaint categories
-- Note: Fully idempotent using DROP IF EXISTS so it can be re-run safely.
-- ==============================================================================

-- 1. HELPER: CREATE IN-APP NOTIFICATION
CREATE OR REPLACE FUNCTION public.create_notification(
    p_user_id UUID,
    p_title TEXT,
    p_message TEXT,
    p_notification_type TEXT,
    p_data JSONB DEFAULT '{}'::JSONB
)
RETURNS public.notifications AS $$
DECLARE
    v_notification public.notifications;
BEGIN
    INSERT INTO public.notifications (user_id, title, message, notification_type, is_read, data)
    VALUES (p_user_id, p_title, p_message, p_notification_type, FALSE, p_data)
    RETURNING * INTO v_notification;

    RETURN v_notification;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public;

-- 2. TRIGGER: AUTOMATIC NOTIFICATIONS ON BOOKING STATUS CHANGE
CREATE OR REPLACE FUNCTION public.handle_booking_notification()
RETURNS TRIGGER AS $$
DECLARE
    v_spot record;
BEGIN
    SELECT title, owner_id INTO v_spot FROM public.parking_spots WHERE id = NEW.spot_id;

    IF TG_OP = 'INSERT' AND NEW.booking_status = 'pending' THEN
        -- Notify Spot Owner
        PERFORM public.create_notification(
            v_spot.owner_id,
            'New Booking Request',
            'A driver requested to book "' || v_spot.title || '" for ' || NEW.booking_date::TEXT,
            'booking_request',
            jsonb_build_object('booking_id', NEW.id, 'spot_id', NEW.spot_id, 'reference', NEW.booking_reference)
        );
    ELSIF TG_OP = 'UPDATE' AND OLD.booking_status <> NEW.booking_status THEN
        IF NEW.booking_status = 'confirmed' THEN
            -- Notify Customer
            PERFORM public.create_notification(
                NEW.customer_id,
                'Booking Request Approved!',
                'Your booking request for "' || v_spot.title || '" has been approved by the owner.',
                'booking_approved',
                jsonb_build_object('booking_id', NEW.id, 'spot_id', NEW.spot_id, 'reference', NEW.booking_reference)
            );
        ELSIF NEW.booking_status = 'rejected' THEN
            -- Notify Customer
            PERFORM public.create_notification(
                NEW.customer_id,
                'Booking Request Declined',
                'Your booking request for "' || v_spot.title || '" was declined.',
                'booking_rejected',
                jsonb_build_object('booking_id', NEW.id, 'spot_id', NEW.spot_id, 'reference', NEW.booking_reference)
            );
        ELSIF NEW.booking_status = 'cancelled' THEN
            -- Notify Host if cancelled by Customer
            IF auth.uid() = NEW.customer_id THEN
                PERFORM public.create_notification(
                    v_spot.owner_id,
                    'Booking Cancelled by Renter',
                    'Booking ' || NEW.booking_reference || ' for "' || v_spot.title || '" was cancelled.',
                    'booking_cancelled',
                    jsonb_build_object('booking_id', NEW.id, 'spot_id', NEW.spot_id, 'reference', NEW.booking_reference)
                );
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_booking_notification ON public.bookings;
CREATE TRIGGER on_booking_notification
    AFTER INSERT OR UPDATE ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION public.handle_booking_notification();

-- 3. FUNCTION: SUBMIT REVIEW (WITH DUPLICATE REVIEW CHECK & COMPLETED BOOKING VERIFICATION)
CREATE OR REPLACE FUNCTION public.submit_review(
    p_booking_id UUID,
    p_rating INT,
    p_review_text TEXT DEFAULT NULL
)
RETURNS public.reviews AS $$
DECLARE
    v_booking public.bookings;
    v_existing_count INT;
    v_new_review public.reviews;
BEGIN
    IF p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'Invalid Rating: Rating must be between 1 and 5 stars.';
    END IF;

    -- Verify booking exists and belongs to customer
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found.';
    END IF;

    IF v_booking.customer_id <> auth.uid() THEN
        RAISE EXCEPTION 'Unauthorized: Only the customer who completed this booking can submit a review.';
    END IF;

    IF v_booking.booking_status <> 'completed' THEN
        RAISE EXCEPTION 'Ineligible: Reviews can only be submitted after a booking is completed.';
    END IF;

    -- Check for duplicate review
    SELECT COUNT(*) INTO v_existing_count FROM public.reviews WHERE booking_id = p_booking_id;
    IF v_existing_count > 0 THEN
        RAISE EXCEPTION 'Duplicate Review: A review has already been submitted for this booking.';
    END IF;

    -- Insert review
    INSERT INTO public.reviews (
        booking_id,
        reviewer_id,
        spot_id,
        rating,
        review_text
    )
    VALUES (
        p_booking_id,
        auth.uid(),
        v_booking.spot_id,
        p_rating,
        p_review_text
    )
    RETURNING * INTO v_new_review;

    RETURN v_new_review;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public;

-- 4. FUNCTION: SUBMIT COMPLAINT / REPORT
CREATE OR REPLACE FUNCTION public.submit_complaint(
    p_subject TEXT,
    p_description TEXT,
    p_spot_id UUID DEFAULT NULL,
    p_booking_id UUID DEFAULT NULL
)
RETURNS public.complaints AS $$
DECLARE
    v_new_complaint public.complaints;
BEGIN
    IF p_subject IS NULL OR LENGTH(TRIM(p_subject)) = 0 THEN
        RAISE EXCEPTION 'Subject is required.';
    END IF;

    IF p_description IS NULL OR LENGTH(TRIM(p_description)) = 0 THEN
        RAISE EXCEPTION 'Description is required.';
    END IF;

    INSERT INTO public.complaints (
        reporter_id,
        spot_id,
        booking_id,
        subject,
        description,
        status
    )
    VALUES (
        auth.uid(),
        p_spot_id,
        p_booking_id,
        p_subject,
        p_description,
        'open'
    )
    RETURNING * INTO v_new_complaint;

    RETURN v_new_complaint;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public;
