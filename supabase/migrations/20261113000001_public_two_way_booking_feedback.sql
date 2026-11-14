-- Public two-way feedback is available once a booking is accepted.

CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
    reviewer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    spot_id UUID NOT NULL REFERENCES public.parking_spots(id) ON DELETE CASCADE,
    reviewer_role TEXT NOT NULL,
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewee_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    review_text TEXT
);

ALTER TABLE public.reviews
    ADD COLUMN IF NOT EXISTS target_user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS comment TEXT,
    ADD COLUMN IF NOT EXISTS reviewee_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS review_text TEXT,
    ADD COLUMN IF NOT EXISTS reviewer_role TEXT NOT NULL DEFAULT 'vehicle_owner';

ALTER TABLE public.reviews
    DROP CONSTRAINT IF EXISTS reviews_reviewer_role_check;

UPDATE public.reviews r
SET target_user_id = COALESCE(
        r.target_user_id,
        r.reviewee_id,
        CASE WHEN r.reviewer_id = s.owner_id THEN b.customer_id ELSE s.owner_id END
    ),
    comment = COALESCE(r.comment, r.review_text),
    reviewer_role = CASE
        WHEN r.reviewer_id = s.owner_id THEN 'spot_owner'
        ELSE 'vehicle_owner'
    END
FROM public.bookings b
JOIN public.parking_spots s ON s.id = b.spot_id
WHERE b.id = r.booking_id;

ALTER TABLE public.reviews
    ALTER COLUMN target_user_id SET NOT NULL,
    ALTER COLUMN reviewer_role SET DEFAULT 'vehicle_owner',
    ADD CONSTRAINT reviews_reviewer_role_check
        CHECK (reviewer_role IN ('vehicle_owner', 'spot_owner'));

ALTER TABLE public.reviews DROP CONSTRAINT IF EXISTS reviews_booking_id_key;
ALTER TABLE public.reviews DROP CONSTRAINT IF EXISTS reviews_booking_reviewer_unique;
ALTER TABLE public.reviews
    ADD CONSTRAINT reviews_booking_reviewer_unique UNIQUE (booking_id, reviewer_id);

CREATE INDEX IF NOT EXISTS idx_reviews_target_user ON public.reviews(target_user_id);
CREATE INDEX IF NOT EXISTS idx_reviews_spot_created_at ON public.reviews(spot_id, created_at DESC);

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Reviews are viewable by everyone" ON public.reviews;
CREATE POLICY "Reviews are viewable by everyone"
    ON public.reviews FOR SELECT
    USING (true);
GRANT SELECT ON public.reviews TO anon, authenticated;

DROP POLICY IF EXISTS "Reviewers can insert reviews for completed bookings" ON public.reviews;
DROP POLICY IF EXISTS "Booking participants can submit feedback after acceptance" ON public.reviews;
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
RETURNS public.reviews AS $$
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

    IF p_rating < 1 OR p_rating > 5 THEN
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
        RAISE EXCEPTION 'Ineligible: Feedback can only be submitted after a booking is accepted.';
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
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, auth;

REVOKE ALL ON FUNCTION public.submit_two_way_review(UUID, INT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_two_way_review(UUID, INT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_review(
    p_booking_id UUID,
    p_rating INT,
    p_review_text TEXT DEFAULT NULL
)
RETURNS public.reviews AS $$
BEGIN
    RETURN public.submit_two_way_review(
        p_booking_id,
        p_rating,
        p_review_text
    );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

REVOKE ALL ON FUNCTION public.submit_review(UUID, INT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_review(UUID, INT, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
