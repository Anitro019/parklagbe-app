-- Ensure the deployed two-way review RPC and INSERT policy accept confirmed bookings.

DROP POLICY IF EXISTS "Reviewers can insert reviews for completed bookings"
    ON public.reviews;
DROP POLICY IF EXISTS "Booking participants can submit feedback after acceptance"
    ON public.reviews;

CREATE POLICY "Booking participants can submit feedback after acceptance"
    ON public.reviews FOR INSERT
    WITH CHECK (
        reviewer_id = auth.uid()
        AND EXISTS (
            SELECT 1
            FROM public.bookings b
            JOIN public.parking_spots s ON s.id = b.spot_id
            WHERE b.id = public.reviews.booking_id
              AND b.booking_status IN ('confirmed', 'completed')
              AND (
                  (
                      b.customer_id = auth.uid()
                      AND public.reviews.target_user_id = s.owner_id
                      AND public.reviews.reviewer_role = 'vehicle_owner'
                  )
                  OR (
                      s.owner_id = auth.uid()
                      AND public.reviews.target_user_id = b.customer_id
                      AND public.reviews.reviewer_role = 'spot_owner'
                  )
              )
        )
    );

CREATE OR REPLACE FUNCTION public.submit_two_way_review(
    p_booking_id UUID,
    p_rating INT,
    p_review_text TEXT DEFAULT NULL
)
RETURNS public.reviews
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_booking public.bookings;
    v_spot_owner_id UUID;
    v_target_user_id UUID;
    v_reviewer_role TEXT;
    v_new_review public.reviews;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: You must be logged in to submit feedback.';
    END IF;

    IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'Invalid Rating: Rating must be between 1 and 5 stars.';
    END IF;

    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found.';
    END IF;

    SELECT owner_id INTO v_spot_owner_id
    FROM public.parking_spots
    WHERE id = v_booking.spot_id;

    IF auth.uid() = v_booking.customer_id THEN
        v_reviewer_role := 'vehicle_owner';
        v_target_user_id := v_spot_owner_id;
    ELSIF auth.uid() = v_spot_owner_id THEN
        v_reviewer_role := 'spot_owner';
        v_target_user_id := v_booking.customer_id;
    ELSE
        RAISE EXCEPTION 'Unauthorized: Only the vehicle owner or spot owner can submit feedback.';
    END IF;

    IF v_booking.booking_status NOT IN ('confirmed', 'completed') THEN
        RAISE EXCEPTION 'Ineligible: Reviews can only be submitted after a booking is confirmed or completed.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.reviews
        WHERE booking_id = p_booking_id
          AND reviewer_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Duplicate Review: You have already submitted feedback for this booking.';
    END IF;

    INSERT INTO public.reviews (
        booking_id,
        reviewer_id,
        target_user_id,
        reviewee_id,
        reviewer_role,
        spot_id,
        rating,
        comment,
        review_text
    )
    VALUES (
        p_booking_id,
        auth.uid(),
        v_target_user_id,
        v_target_user_id,
        v_reviewer_role,
        v_booking.spot_id,
        p_rating,
        p_review_text,
        p_review_text
    )
    RETURNING * INTO v_new_review;

    RETURN v_new_review;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_two_way_review(UUID, INT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_two_way_review(UUID, INT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_review(
    p_booking_id UUID,
    p_rating INT,
    p_review_text TEXT DEFAULT NULL
)
RETURNS public.reviews
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
    RETURN public.submit_two_way_review(
        p_booking_id,
        p_rating,
        p_review_text
    );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_review(UUID, INT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_review(UUID, INT, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
