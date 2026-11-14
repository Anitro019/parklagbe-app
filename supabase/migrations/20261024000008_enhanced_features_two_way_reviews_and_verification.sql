-- ==============================================================================
-- Migration: 20261024000008_enhanced_features_two_way_reviews_and_verification.sql
-- Description: Two-way reviews, identity verification, report categories, and storage bucket
-- Note: Fully idempotent using IF NOT EXISTS so it can be re-run safely.
-- ==============================================================================

-- 1. PROFILES TABLE: Identity & Vehicle Verification Columns
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS nid_number TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS driving_license_number TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS verification_doc_url TEXT;

-- 2. REVIEWS TABLE: Upgrade to Two-Way Reviews (Reviewer & Reviewee)
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS reviewee_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS reviewer_role TEXT DEFAULT 'customer' CHECK (reviewer_role IN ('customer', 'owner'));

-- Drop single-column unique constraint on booking_id if exists to allow two-way review (one by customer, one by host)
ALTER TABLE public.reviews DROP CONSTRAINT IF EXISTS reviews_booking_id_key;
ALTER TABLE public.reviews DROP CONSTRAINT IF EXISTS reviews_booking_reviewer_unique;
ALTER TABLE public.reviews ADD CONSTRAINT reviews_booking_reviewer_unique UNIQUE (booking_id, reviewer_id);

-- 3. REPORTS / COMPLAINTS TABLE: Add reported_user_id and issue_type
ALTER TABLE public.complaints ADD COLUMN IF NOT EXISTS reported_user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.complaints ADD COLUMN IF NOT EXISTS issue_type TEXT;

-- 4. STORAGE BUCKET: Private verification_docs bucket for NID & Driving License Documents
INSERT INTO storage.buckets (id, name, public)
VALUES ('verification_docs', 'verification_docs', false)
ON CONFLICT (id) DO UPDATE SET public = false;

-- Policies for verification_docs
DROP POLICY IF EXISTS "Authenticated Users Upload Own verification_docs" ON storage.objects;
CREATE POLICY "Authenticated Users Upload Own verification_docs"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'verification_docs'
        AND auth.role() = 'authenticated'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS "Users Read Own verification_docs or Admin" ON storage.objects;
CREATE POLICY "Users Read Own verification_docs or Admin"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'verification_docs'
        AND ( (storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid()) )
    );

-- 5. FUNCTION: SUBMIT TWO-WAY REVIEW (CUSTOMER OR HOST)
CREATE OR REPLACE FUNCTION public.submit_two_way_review(
    p_booking_id UUID,
    p_rating INT,
    p_review_text TEXT DEFAULT NULL
)
RETURNS public.reviews AS $$
DECLARE
    v_booking public.bookings;
    v_spot record;
    v_reviewer_role TEXT;
    v_reviewee_id UUID;
    v_existing_count INT;
    v_new_review public.reviews;
BEGIN
    IF p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'Invalid Rating: Rating must be between 1 and 5 stars.';
    END IF;

    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found.';
    END IF;

    SELECT owner_id INTO v_spot FROM public.parking_spots WHERE id = v_booking.spot_id;

    -- Determine role & reviewee
    IF auth.uid() = v_booking.customer_id THEN
        v_reviewer_role := 'customer';
        v_reviewee_id := v_spot.owner_id;
    ELSIF auth.uid() = v_spot.owner_id THEN
        v_reviewer_role := 'owner';
        v_reviewee_id := v_booking.customer_id;
    ELSE
        RAISE EXCEPTION 'Unauthorized: Only the customer or spot owner of this booking can leave a review.';
    END IF;

    IF v_booking.booking_status NOT IN ('confirmed', 'active', 'completed') THEN
        RAISE EXCEPTION 'Ineligible: Feedback can only be submitted after a booking is accepted (confirmed).';
    END IF;

    -- Check duplicate review by this user on this booking
    SELECT COUNT(*) INTO v_existing_count
    FROM public.reviews
    WHERE booking_id = p_booking_id AND reviewer_id = auth.uid();

    IF v_existing_count > 0 THEN
        RAISE EXCEPTION 'Duplicate Review: You have already submitted a review for this booking.';
    END IF;

    INSERT INTO public.reviews (
        booking_id,
        reviewer_id,
        reviewee_id,
        reviewer_role,
        spot_id,
        rating,
        review_text
    )
    VALUES (
        p_booking_id,
        auth.uid(),
        v_reviewee_id,
        v_reviewer_role,
        v_booking.spot_id,
        p_rating,
        p_review_text
    )
    RETURNING * INTO v_new_review;

    RETURN v_new_review;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public;
