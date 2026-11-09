-- ==============================================================================
-- Migration: 20261024000003_create_storage_buckets_and_policies.sql
-- Description: Creates storage buckets and RLS policies for parking-photos and profile-photos
-- Note: Fully idempotent using DROP IF EXISTS so it can be re-run safely.
-- ==============================================================================

-- 1. CREATE STORAGE BUCKETS IF NOT EXISTS
INSERT INTO storage.buckets (id, name, public)
VALUES
    ('parking-photos', 'parking-photos', true),
    ('profile-photos', 'profile-photos', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. POLICIES FOR parking-photos BUCKET
DROP POLICY IF EXISTS "Public Read Access for parking-photos" ON storage.objects;
CREATE POLICY "Public Read Access for parking-photos"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'parking-photos');

DROP POLICY IF EXISTS "Authenticated Users Upload to parking-photos" ON storage.objects;
CREATE POLICY "Authenticated Users Upload to parking-photos"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'parking-photos'
        AND auth.role() = 'authenticated'
    );

DROP POLICY IF EXISTS "Users Update Own parking-photos" ON storage.objects;
CREATE POLICY "Users Update Own parking-photos"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'parking-photos'
        AND ( (storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid()) )
    );

DROP POLICY IF EXISTS "Users Delete Own parking-photos" ON storage.objects;
CREATE POLICY "Users Delete Own parking-photos"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'parking-photos'
        AND ( (storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid()) )
    );

-- 3. POLICIES FOR profile-photos BUCKET
DROP POLICY IF EXISTS "Public Read Access for profile-photos" ON storage.objects;
CREATE POLICY "Public Read Access for profile-photos"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'profile-photos');

DROP POLICY IF EXISTS "Authenticated Users Upload Own profile-photo" ON storage.objects;
CREATE POLICY "Authenticated Users Upload Own profile-photo"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'profile-photos'
        AND auth.role() = 'authenticated'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS "Users Update Own profile-photo" ON storage.objects;
CREATE POLICY "Users Update Own profile-photo"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'profile-photos'
        AND ( (storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid()) )
    );

DROP POLICY IF EXISTS "Users Delete Own profile-photo" ON storage.objects;
CREATE POLICY "Users Delete Own profile-photo"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'profile-photos'
        AND ( (storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid()) )
    );
