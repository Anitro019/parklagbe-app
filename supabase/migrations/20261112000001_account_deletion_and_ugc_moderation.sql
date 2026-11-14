-- Account deletion, user-generated-content moderation, and public deletion requests.

CREATE TABLE IF NOT EXISTS public.deletion_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email_or_phone TEXT NOT NULL CHECK (char_length(btrim(email_or_phone)) BETWEEN 3 AND 254),
    reason TEXT NOT NULL CHECK (char_length(btrim(reason)) BETWEEN 3 AND 2000),
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'under_review', 'completed', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.deletion_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can submit a deletion request" ON public.deletion_requests;
CREATE POLICY "Anyone can submit a deletion request"
    ON public.deletion_requests FOR INSERT
    TO anon, authenticated
    WITH CHECK (
        char_length(btrim(email_or_phone)) BETWEEN 3 AND 254
        AND char_length(btrim(reason)) BETWEEN 3 AND 2000
    );
REVOKE ALL ON public.deletion_requests FROM anon, authenticated, PUBLIC;
GRANT INSERT ON public.deletion_requests TO anon, authenticated;

DROP POLICY IF EXISTS "Admins review deletion requests" ON public.deletion_requests;
CREATE POLICY "Admins review deletion requests"
    ON public.deletion_requests FOR SELECT
    TO authenticated
    USING (public.is_admin(auth.uid()));
DROP POLICY IF EXISTS "Admins update deletion requests" ON public.deletion_requests;
CREATE POLICY "Admins update deletion requests"
    ON public.deletion_requests FOR UPDATE
    TO authenticated
    USING (public.is_admin(auth.uid()))
    WITH CHECK (public.is_admin(auth.uid()));
GRANT SELECT, UPDATE ON public.deletion_requests TO authenticated;

CREATE TABLE IF NOT EXISTS public.content_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reported_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    spot_id UUID REFERENCES public.parking_spots(id) ON DELETE SET NULL,
    review_id UUID REFERENCES public.reviews(id) ON DELETE SET NULL,
    reason TEXT NOT NULL CHECK (reason IN (
        'Spam/Fake Spot',
        'Inappropriate Photo',
        'Abusive Review',
        'Misleading Info'
    )),
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'under_review', 'resolved', 'dismissed')),
    admin_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (spot_id IS NOT NULL OR review_id IS NOT NULL OR reported_user_id IS NOT NULL)
);

ALTER TABLE public.content_reports
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'open';
ALTER TABLE public.content_reports
    ADD COLUMN IF NOT EXISTS admin_notes TEXT;
ALTER TABLE public.content_reports
    DROP CONSTRAINT IF EXISTS content_reports_status_check;
ALTER TABLE public.content_reports
    ADD CONSTRAINT content_reports_status_check
    CHECK (status IN ('open', 'under_review', 'resolved', 'dismissed'));

CREATE INDEX IF NOT EXISTS idx_content_reports_created_at
    ON public.content_reports(created_at DESC);
ALTER TABLE public.content_reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users submit reports as themselves" ON public.content_reports;
CREATE POLICY "Users submit reports as themselves"
    ON public.content_reports FOR INSERT
    TO authenticated
    WITH CHECK (reporter_id = auth.uid());
DROP POLICY IF EXISTS "Users read their own reports" ON public.content_reports;
CREATE POLICY "Users read their own reports"
    ON public.content_reports FOR SELECT
    TO authenticated
    USING (reporter_id = auth.uid() OR public.is_admin(auth.uid()));
DROP POLICY IF EXISTS "Admins update content reports" ON public.content_reports;
CREATE POLICY "Admins update content reports"
    ON public.content_reports FOR UPDATE
    TO authenticated
    USING (public.is_admin(auth.uid()))
    WITH CHECK (public.is_admin(auth.uid()));
GRANT INSERT, SELECT, UPDATE ON public.content_reports TO authenticated;

CREATE TABLE IF NOT EXISTS public.blocked_users (
    blocker_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    blocked_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (blocker_id, blocked_user_id),
    CHECK (blocker_id <> blocked_user_id)
);

ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users read their own blocks" ON public.blocked_users;
CREATE POLICY "Users read their own blocks"
    ON public.blocked_users FOR SELECT
    TO authenticated
    USING (blocker_id = auth.uid());
DROP POLICY IF EXISTS "Users block others as themselves" ON public.blocked_users;
CREATE POLICY "Users block others as themselves"
    ON public.blocked_users FOR INSERT
    TO authenticated
    WITH CHECK (blocker_id = auth.uid() AND blocker_id <> blocked_user_id);
DROP POLICY IF EXISTS "Users unblock others as themselves" ON public.blocked_users;
CREATE POLICY "Users unblock others as themselves"
    ON public.blocked_users FOR DELETE
    TO authenticated
    USING (blocker_id = auth.uid());
GRANT SELECT, INSERT, DELETE ON public.blocked_users TO authenticated;

-- Spot image object paths are keyed by spot ID, so authorize owners while the
-- spot row still exists and before the deletion RPC cascades its records.
DROP POLICY IF EXISTS "Owners delete their spot image objects" ON storage.objects;
CREATE POLICY "Owners delete their spot image objects"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        (
            bucket_id = 'spot_images'
            AND (storage.foldername(name))[1] = auth.uid()::TEXT
        )
        OR (
            bucket_id IN ('parking-photos', 'spot_images')
            AND EXISTS (
                SELECT 1
                FROM public.parking_spots
                WHERE id::TEXT = (storage.foldername(name))[1]
                  AND owner_id = auth.uid()
            )
        )
    );

DROP POLICY IF EXISTS "Users delete their own verification documents" ON storage.objects;
CREATE POLICY "Users delete their own verification documents"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'verification_docs'
        AND (storage.foldername(name))[1] = auth.uid()::TEXT
    );

CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS VOID
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: You must be logged in to delete your account.';
    END IF;

    DELETE FROM public.profiles WHERE id = v_user_id;
    DELETE FROM auth.users WHERE id = v_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_user_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;