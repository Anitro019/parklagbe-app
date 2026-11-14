-- ParkLagbee full Supabase schema sync
-- Consolidated from supabase/migrations and the Flutter data layer.
-- Review against your project's existing data and policies before running in production.
-- This script is designed to be rerunnable; it does not delete application data.


-- ==============================================================================
-- Migration: 20261024000001_create_parklagbee_schema.sql
-- Description: Core database tables for ParkLagbee (Profiles, Spots, Photos, Bookings, Reviews, Notifications, Complaints)
-- Note: Fully idempotent using IF NOT EXISTS and ALTER TABLE ADD COLUMN so it can be re-run safely.
-- ==============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. PROFILES TABLE (Extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    phone TEXT,
    avatar_url TEXT,
    address TEXT,
    account_type TEXT NOT NULL DEFAULT 'driver' CHECK (account_type IN ('driver', 'host', 'admin')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. PARKING SPOTS TABLE
CREATE TABLE IF NOT EXISTS public.parking_spots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    address TEXT NOT NULL,
    division TEXT NOT NULL, -- e.g. Dhaka, Chittagong, Sylhet
    district TEXT NOT NULL, -- e.g. Dhaka, Gazipur, Narayanganj
    area TEXT NOT NULL,     -- e.g. Gulshan, Dhanmondi, Banani, Uttara, Mirpur
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    google_maps_url TEXT,
    vehicle_types TEXT[] NOT NULL DEFAULT ARRAY['car'], -- ['car', 'bike', 'microbus', 'suv']
    capacity INTEGER NOT NULL DEFAULT 1 CHECK (capacity > 0),
    hourly_price NUMERIC(10,2) CHECK (hourly_price >= 0),
    daily_price NUMERIC(10,2) CHECK (daily_price >= 0),
    monthly_price NUMERIC(10,2) CHECK (monthly_price >= 0),
    available_hours_start TIME NOT NULL DEFAULT '00:00:00',
    available_hours_end TIME NOT NULL DEFAULT '23:59:59',
    available_days TEXT[] NOT NULL DEFAULT ARRAY['mon','tue','wed','thu','fri','sat','sun'],
    available_from TIMESTAMPTZ,
    available_to TIMESTAMPTZ,
    rules TEXT,
    facilities TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[], -- ['cctv', 'guarded', 'covered', 'gate_pass', 'ev_charging']
    advance_requirement_percentage NUMERIC(5,2) NOT NULL DEFAULT 0.00 CHECK (advance_requirement_percentage >= 0 AND advance_requirement_percentage <= 100),
    contact_phone TEXT,
    is_contact_visible BOOLEAN NOT NULL DEFAULT TRUE,
    approval_status TEXT NOT NULL DEFAULT 'approved' CHECK (approval_status IN ('pending', 'approved', 'rejected', 'suspended')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure columns exist on existing tables if created prior to contact fields
ALTER TABLE public.parking_spots ADD COLUMN IF NOT EXISTS contact_phone TEXT;
ALTER TABLE public.parking_spots ADD COLUMN IF NOT EXISTS is_contact_visible BOOLEAN NOT NULL DEFAULT TRUE;

-- INDEXES for parking spot searching
CREATE INDEX IF NOT EXISTS idx_parking_spots_owner ON public.parking_spots(owner_id);
CREATE INDEX IF NOT EXISTS idx_parking_spots_area_district ON public.parking_spots(district, area);
CREATE INDEX IF NOT EXISTS idx_parking_spots_approval ON public.parking_spots(approval_status, is_active);

-- 3. PARKING PHOTOS TABLE
CREATE TABLE IF NOT EXISTS public.parking_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spot_id UUID NOT NULL REFERENCES public.parking_spots(id) ON DELETE CASCADE,
    storage_path TEXT NOT NULL,
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. PARKING CLOSED DATES TABLE
CREATE TABLE IF NOT EXISTS public.parking_closed_dates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spot_id UUID NOT NULL REFERENCES public.parking_spots(id) ON DELETE CASCADE,
    closed_date DATE NOT NULL,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (spot_id, closed_date)
);

-- 5. BOOKINGS TABLE
CREATE TABLE IF NOT EXISTS public.bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_reference TEXT UNIQUE NOT NULL,
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    spot_id UUID NOT NULL REFERENCES public.parking_spots(id) ON DELETE CASCADE,
    vehicle_type TEXT NOT NULL,
    vehicle_number TEXT,
    booking_date DATE NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    duration_hours NUMERIC(10,2) NOT NULL,
    rental_type TEXT NOT NULL DEFAULT 'hourly' CHECK (rental_type IN ('hourly', 'daily', 'monthly')),
    price_breakdown JSONB NOT NULL,
    total_price NUMERIC(10,2) NOT NULL,
    advance_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    booking_status TEXT NOT NULL DEFAULT 'pending' CHECK (booking_status IN ('pending', 'confirmed', 'active', 'completed', 'cancelled', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- INDEXES for booking queries
CREATE INDEX IF NOT EXISTS idx_bookings_customer ON public.bookings(customer_id);
CREATE INDEX IF NOT EXISTS idx_bookings_spot ON public.bookings(spot_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status_dates ON public.bookings(spot_id, booking_status, start_time, end_time);

-- 6. REVIEWS TABLE
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
    reviewer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reviewer_role TEXT NOT NULL,
    spot_id UUID NOT NULL REFERENCES public.parking_spots(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    reviewee_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    review_text TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    notification_type TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    data JSONB DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON public.notifications(user_id, is_read);

-- 8. COMPLAINTS & REPORTS TABLE
CREATE TABLE IF NOT EXISTS public.complaints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    spot_id UUID REFERENCES public.parking_spots(id) ON DELETE SET NULL,
    booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
    subject TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'under_review', 'investigating', 'resolved', 'dismissed')),
    admin_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. ADMIN AUDIT LOGS TABLE
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    action TEXT,
    action_type TEXT,
    target_type TEXT,
    target_id UUID,
    details JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Reconcile columns when a table predates one or more migrations.
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS full_name TEXT NOT NULL DEFAULT 'ParkLagbee User',
    ADD COLUMN IF NOT EXISTS phone TEXT,
    ADD COLUMN IF NOT EXISTS avatar_url TEXT,
    ADD COLUMN IF NOT EXISTS address TEXT,
    ADD COLUMN IF NOT EXISTS account_type TEXT NOT NULL DEFAULT 'driver',
    ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS nid_number TEXT,
    ADD COLUMN IF NOT EXISTS driving_license_number TEXT,
    ADD COLUMN IF NOT EXISTS verification_doc_url TEXT,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE public.parking_spots
    ADD COLUMN IF NOT EXISTS owner_id UUID,
    ADD COLUMN IF NOT EXISTS title TEXT,
    ADD COLUMN IF NOT EXISTS description TEXT,
    ADD COLUMN IF NOT EXISTS address TEXT,
    ADD COLUMN IF NOT EXISTS division TEXT,
    ADD COLUMN IF NOT EXISTS district TEXT,
    ADD COLUMN IF NOT EXISTS area TEXT,
    ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS google_maps_url TEXT,
    ADD COLUMN IF NOT EXISTS vehicle_types TEXT[] NOT NULL DEFAULT ARRAY['car']::TEXT[],
    ADD COLUMN IF NOT EXISTS capacity INTEGER NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS hourly_price NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS daily_price NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS monthly_price NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS available_hours_start TIME NOT NULL DEFAULT '00:00:00',
    ADD COLUMN IF NOT EXISTS available_hours_end TIME NOT NULL DEFAULT '23:59:59',
    ADD COLUMN IF NOT EXISTS available_days TEXT[] NOT NULL DEFAULT ARRAY['mon','tue','wed','thu','fri','sat','sun']::TEXT[],
    ADD COLUMN IF NOT EXISTS available_start_date DATE,
    ADD COLUMN IF NOT EXISTS available_end_date DATE,
    ADD COLUMN IF NOT EXISTS available_from TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS available_to TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS rules TEXT,
    ADD COLUMN IF NOT EXISTS facilities TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    ADD COLUMN IF NOT EXISTS advance_requirement_percentage NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS contact_phone TEXT,
    ADD COLUMN IF NOT EXISTS is_contact_visible BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL DEFAULT 'approved',
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE public.parking_photos
    ADD COLUMN IF NOT EXISTS spot_id UUID,
    ADD COLUMN IF NOT EXISTS storage_path TEXT,
    ADD COLUMN IF NOT EXISTS display_order INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE public.parking_closed_dates
    ADD COLUMN IF NOT EXISTS spot_id UUID,
    ADD COLUMN IF NOT EXISTS closed_date DATE,
    ADD COLUMN IF NOT EXISTS reason TEXT,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE public.bookings
    ADD COLUMN IF NOT EXISTS booking_reference TEXT,
    ADD COLUMN IF NOT EXISTS customer_id UUID,
    ADD COLUMN IF NOT EXISTS spot_id UUID,
    ADD COLUMN IF NOT EXISTS vehicle_type TEXT,
    ADD COLUMN IF NOT EXISTS vehicle_number TEXT,
    ADD COLUMN IF NOT EXISTS booking_date DATE,
    ADD COLUMN IF NOT EXISTS start_time TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS end_time TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS duration_hours NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS rental_type TEXT NOT NULL DEFAULT 'hourly',
    ADD COLUMN IF NOT EXISTS price_breakdown JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS total_price NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS advance_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS booking_status TEXT NOT NULL DEFAULT 'pending',
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE public.reviews
    ADD COLUMN IF NOT EXISTS booking_id UUID,
    ADD COLUMN IF NOT EXISTS reviewer_id UUID,
    ADD COLUMN IF NOT EXISTS target_user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS reviewee_id UUID,
    ADD COLUMN IF NOT EXISTS reviewer_role TEXT NOT NULL DEFAULT 'customer',
    ADD COLUMN IF NOT EXISTS spot_id UUID,
    ADD COLUMN IF NOT EXISTS rating INTEGER,
    ADD COLUMN IF NOT EXISTS comment TEXT,
    ADD COLUMN IF NOT EXISTS review_text TEXT,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE public.notifications
    ADD COLUMN IF NOT EXISTS user_id UUID,
    ADD COLUMN IF NOT EXISTS title TEXT,
    ADD COLUMN IF NOT EXISTS message TEXT,
    ADD COLUMN IF NOT EXISTS notification_type TEXT,
    ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS data JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE public.complaints
    ADD COLUMN IF NOT EXISTS reporter_id UUID,
    ADD COLUMN IF NOT EXISTS spot_id UUID,
    ADD COLUMN IF NOT EXISTS booking_id UUID,
    ADD COLUMN IF NOT EXISTS subject TEXT,
    ADD COLUMN IF NOT EXISTS description TEXT,
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'open',
    ADD COLUMN IF NOT EXISTS admin_notes TEXT,
    ADD COLUMN IF NOT EXISTS reported_user_id UUID,
    ADD COLUMN IF NOT EXISTS issue_type TEXT,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE public.admin_audit_logs
    ADD COLUMN IF NOT EXISTS admin_id UUID,
    ADD COLUMN IF NOT EXISTS action TEXT,
    ADD COLUMN IF NOT EXISTS action_type TEXT,
    ADD COLUMN IF NOT EXISTS target_type TEXT,
    ADD COLUMN IF NOT EXISTS target_id UUID,
    ADD COLUMN IF NOT EXISTS details JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE public.admin_audit_logs ALTER COLUMN action_type DROP NOT NULL;
ALTER TABLE public.complaints DROP CONSTRAINT IF EXISTS complaints_status_check;
ALTER TABLE public.complaints
    ADD CONSTRAINT complaints_status_check
    CHECK (status IN ('open', 'under_review', 'investigating', 'resolved', 'dismissed'));


-- ==============================================================================
-- Migration: 20261024000002_create_security_triggers_and_rls.sql
-- Description: Helper functions, triggers, and Row Level Security (RLS) policies
-- Note: Fully idempotent using DROP IF EXISTS so it can be re-run safely.
-- ==============================================================================

-- 1. HELPER FUNCTION: CHECK IF USER IS ADMIN
CREATE OR REPLACE FUNCTION public.is_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = user_id AND account_type = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 2. TRIGGER FUNCTION: AUTOMATIC PROFILE CREATION ON USER SIGNUP
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    requested_role TEXT;
BEGIN
    requested_role := LOWER(COALESCE(
        NEW.raw_user_meta_data->>'account_type',
        NEW.raw_user_meta_data->>'role',
        'driver'
    ));

    -- Support 'host', 'spot_owner', 'owner' mapping safely to 'host'
    IF requested_role IN ('host', 'spot_owner', 'owner') THEN
        requested_role := 'host';
    ELSE
        requested_role := 'driver';
    END IF;

    INSERT INTO public.profiles (id, full_name, phone, account_type)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'ParkLagbee User'),
        COALESCE(NEW.raw_user_meta_data->>'phone', NEW.phone),
        requested_role
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Guarantee auth.users insert NEVER aborts or fails trigger, ensuring confirmation email is dispatched
    INSERT INTO public.profiles (id, full_name, account_type)
    VALUES (NEW.id, 'ParkLagbee User', 'driver')
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. TRIGGER FUNCTION: PREVENT NON-ADMINS FROM ELEVATING TO ADMIN ROLE
CREATE OR REPLACE FUNCTION public.prevent_admin_elevation()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.account_type = 'admin' AND (OLD.account_type IS NULL OR OLD.account_type <> 'admin') THEN
        IF NOT public.is_admin(auth.uid()) THEN
            RAISE EXCEPTION 'Unauthorized: Only an administrator can assign the admin role.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS check_admin_elevation ON public.profiles;
CREATE TRIGGER check_admin_elevation
    BEFORE INSERT OR UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.prevent_admin_elevation();

-- 4. ENABLE RLS ON ALL TABLES
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parking_spots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parking_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parking_closed_dates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

-- ==============================================================================
-- RLS POLICIES FOR PROFILES
-- ==============================================================================
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Users can view their own profile and admins can view any" ON public.profiles;
CREATE POLICY "Users can view their own profile and admins can view any"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id OR public.is_admin(auth.uid()));

CREATE OR REPLACE VIEW public.public_profiles
WITH (security_barrier = true)
AS
SELECT id, full_name, phone, avatar_url, address, account_type, is_verified, created_at, updated_at
FROM public.profiles;
GRANT SELECT ON public.public_profiles TO anon, authenticated;

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile or admins can update any" ON public.profiles;
CREATE POLICY "Users can update their own profile or admins can update any"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id OR public.is_admin(auth.uid()))
    WITH CHECK (auth.uid() = id OR public.is_admin(auth.uid()));

-- ==============================================================================
-- RLS POLICIES FOR PARKING_SPOTS
-- ==============================================================================
DROP POLICY IF EXISTS "Anyone can view approved and active parking spots" ON public.parking_spots;
CREATE POLICY "Anyone can view approved and active parking spots"
    ON public.parking_spots FOR SELECT
    USING (
        (approval_status = 'approved' AND is_active = true)
        OR owner_id = auth.uid()
        OR public.is_admin(auth.uid())
    );

DROP POLICY IF EXISTS "Hosts can create parking spots" ON public.parking_spots;
CREATE POLICY "Hosts can create parking spots"
    ON public.parking_spots FOR INSERT
    WITH CHECK (
        auth.uid() = owner_id
    );

DROP POLICY IF EXISTS "Owners can update their parking spots, admins can update any" ON public.parking_spots;
CREATE POLICY "Owners can update their parking spots, admins can update any"
    ON public.parking_spots FOR UPDATE
    USING (owner_id = auth.uid() OR public.is_admin(auth.uid()))
    WITH CHECK (owner_id = auth.uid() OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Owners or admins can delete parking spots" ON public.parking_spots;
CREATE POLICY "Owners or admins can delete parking spots"
    ON public.parking_spots FOR DELETE
    USING (owner_id = auth.uid() OR public.is_admin(auth.uid()));

-- ==============================================================================
-- RLS POLICIES FOR PARKING_PHOTOS
-- ==============================================================================
DROP POLICY IF EXISTS "Anyone can view photos for approved spots or owners for their spots" ON public.parking_photos;
CREATE POLICY "Anyone can view photos for approved spots or owners for their spots"
    ON public.parking_photos FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.parking_spots s
            WHERE s.id = spot_id
            AND ( (s.approval_status = 'approved' AND s.is_active = true) OR s.owner_id = auth.uid() OR public.is_admin(auth.uid()) )
        )
    );

DROP POLICY IF EXISTS "Spot owners can insert photos" ON public.parking_photos;
CREATE POLICY "Spot owners can insert photos"
    ON public.parking_photos FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.parking_spots s
            WHERE s.id = spot_id AND (s.owner_id = auth.uid() OR public.is_admin(auth.uid()))
        )
    );

DROP POLICY IF EXISTS "Spot owners can update photos" ON public.parking_photos;
CREATE POLICY "Spot owners can update photos"
    ON public.parking_photos FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.parking_spots s
            WHERE s.id = spot_id AND (s.owner_id = auth.uid() OR public.is_admin(auth.uid()))
        )
    );

DROP POLICY IF EXISTS "Spot owners can delete photos" ON public.parking_photos;
CREATE POLICY "Spot owners can delete photos"
    ON public.parking_photos FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.parking_spots s
            WHERE s.id = spot_id AND (s.owner_id = auth.uid() OR public.is_admin(auth.uid()))
        )
    );

-- ==============================================================================
-- RLS POLICIES FOR PARKING_CLOSED_DATES
-- ==============================================================================
DROP POLICY IF EXISTS "Anyone can view closed dates" ON public.parking_closed_dates;
CREATE POLICY "Anyone can view closed dates"
    ON public.parking_closed_dates FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Spot owners or admins can manage closed dates" ON public.parking_closed_dates;
CREATE POLICY "Spot owners or admins can manage closed dates"
    ON public.parking_closed_dates FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.parking_spots s
            WHERE s.id = spot_id AND (s.owner_id = auth.uid() OR public.is_admin(auth.uid()))
        )
    );

-- ==============================================================================
-- RLS POLICIES FOR BOOKINGS
-- ==============================================================================
DROP POLICY IF EXISTS "Customers, spot owners, and admins can view bookings" ON public.bookings;
CREATE POLICY "Customers, spot owners, and admins can view bookings"
    ON public.bookings FOR SELECT
    USING (
        customer_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.parking_spots s
            WHERE s.id = spot_id AND s.owner_id = auth.uid()
        )
        OR public.is_admin(auth.uid())
    );

DROP POLICY IF EXISTS "Authenticated customers can create bookings" ON public.bookings;
CREATE POLICY "Authenticated customers can create bookings"
    ON public.bookings FOR INSERT
    WITH CHECK (customer_id = auth.uid());

DROP POLICY IF EXISTS "Customers, spot owners, and admins can update bookings" ON public.bookings;
CREATE POLICY "Customers, spot owners, and admins can update bookings"
    ON public.bookings FOR UPDATE
    USING (
        customer_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.parking_spots s
            WHERE s.id = spot_id AND s.owner_id = auth.uid()
        )
        OR public.is_admin(auth.uid())
    );

-- ==============================================================================
-- RLS POLICIES FOR REVIEWS
-- ==============================================================================
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

DROP POLICY IF EXISTS "Reviewers or admins can update/delete reviews" ON public.reviews;
CREATE POLICY "Reviewers or admins can update/delete reviews"
    ON public.reviews FOR UPDATE
    USING (reviewer_id = auth.uid() OR public.is_admin(auth.uid()));

-- ==============================================================================
-- RLS POLICIES FOR NOTIFICATIONS
-- ==============================================================================
DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
CREATE POLICY "Users can view their own notifications"
    ON public.notifications FOR SELECT
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
CREATE POLICY "Users can update their own notifications"
    ON public.notifications FOR UPDATE
    USING (user_id = auth.uid());

-- Notifications are consumed through Supabase Realtime streams in the app.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
       AND NOT EXISTS (
           SELECT 1
           FROM pg_publication_tables
           WHERE pubname = 'supabase_realtime'
             AND schemaname = 'public'
             AND tablename = 'notifications'
       )
    THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
END;
$$;

-- ==============================================================================
-- RLS POLICIES FOR COMPLAINTS
-- ==============================================================================
DROP POLICY IF EXISTS "Reporters and admins can view complaints" ON public.complaints;
CREATE POLICY "Reporters and admins can view complaints"
    ON public.complaints FOR SELECT
    USING (reporter_id = auth.uid() OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Authenticated users can submit complaints" ON public.complaints;
CREATE POLICY "Authenticated users can submit complaints"
    ON public.complaints FOR INSERT
    WITH CHECK (reporter_id = auth.uid());

DROP POLICY IF EXISTS "Reporters or admins can update complaints" ON public.complaints;
CREATE POLICY "Reporters or admins can update complaints"
    ON public.complaints FOR UPDATE
    USING (reporter_id = auth.uid() OR public.is_admin(auth.uid()));

-- ==============================================================================
-- RLS POLICIES FOR ADMIN_AUDIT_LOGS
-- ==============================================================================
DROP POLICY IF EXISTS "Admins can view audit logs" ON public.admin_audit_logs;
CREATE POLICY "Admins can view audit logs"
    ON public.admin_audit_logs FOR SELECT
    USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Admins can insert audit logs" ON public.admin_audit_logs;
CREATE POLICY "Admins can insert audit logs"
    ON public.admin_audit_logs FOR INSERT
    WITH CHECK (public.is_admin(auth.uid()));


-- ==============================================================================
-- Migration: 20261024000003_create_storage_buckets_and_policies.sql
-- Description: Creates storage buckets and RLS policies for parking-photos and profile-photos
-- Note: Fully idempotent using DROP IF EXISTS so it can be re-run safely.
-- ==============================================================================

-- 1. CREATE STORAGE BUCKETS IF NOT EXISTS
INSERT INTO storage.buckets (id, name, public)
VALUES
    ('parking-photos', 'parking-photos', true),
    ('profile-photos', 'profile-photos', true),
    ('spot_images', 'spot_images', true)
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

-- 4. POLICIES FOR legacy spot_images bucket.
DROP POLICY IF EXISTS "Public Read Access for spot_images" ON storage.objects;
CREATE POLICY "Public Read Access for spot_images"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'spot_images');

DROP POLICY IF EXISTS "Authenticated Users Upload to spot_images" ON storage.objects;
CREATE POLICY "Authenticated Users Upload to spot_images"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'spot_images'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR EXISTS (
                SELECT 1 FROM public.parking_spots
                WHERE id::text = (storage.foldername(name))[1]
                  AND owner_id = auth.uid()
            )
        )
    );

DROP POLICY IF EXISTS "Users Update Own spot_images" ON storage.objects;
CREATE POLICY "Users Update Own spot_images"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'spot_images'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR public.is_admin(auth.uid())
            OR EXISTS (
                SELECT 1 FROM public.parking_spots
                WHERE id::text = (storage.foldername(name))[1]
                  AND owner_id = auth.uid()
            )
        )
    )
    WITH CHECK (
        bucket_id = 'spot_images'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR public.is_admin(auth.uid())
            OR EXISTS (
                SELECT 1 FROM public.parking_spots
                WHERE id::text = (storage.foldername(name))[1]
                  AND owner_id = auth.uid()
            )
        )
    );

DROP POLICY IF EXISTS "Users Delete Own spot_images" ON storage.objects;
CREATE POLICY "Users Delete Own spot_images"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'spot_images'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR public.is_admin(auth.uid())
            OR EXISTS (
                SELECT 1 FROM public.parking_spots
                WHERE id::text = (storage.foldername(name))[1]
                  AND owner_id = auth.uid()
            )
        )
    );


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


-- ==============================================================================
-- Migration: 20261024000006_create_account_deletion_function.sql
-- Description: Server-side RPC for user self-account deletion (Google Play Store compliance)
-- Note: Fully idempotent using DROP IF EXISTS so it can be re-run safely.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS VOID AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: You must be logged in to delete your account.';
    END IF;

    -- Delete profile (Cascade deletes user listings, bookings, reviews, notifications, complaints)
    DELETE FROM public.profiles WHERE id = v_user_id;

    -- Delete auth user
    DELETE FROM auth.users WHERE id = v_user_id;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public;


-- ==============================================================================
-- Migration: 20261024000007_create_spot_availabilities.sql
-- Description: Date ranges (start_date, end_date) and spot_availabilities table
-- Note: Fully idempotent using IF NOT EXISTS so it can be re-run safely.
-- ==============================================================================

-- 1. Add Date Range Columns to parking_spots table
ALTER TABLE public.parking_spots ADD COLUMN IF NOT EXISTS available_start_date DATE;
ALTER TABLE public.parking_spots ADD COLUMN IF NOT EXISTS available_end_date DATE;

-- 2. Create SPOT AVAILABILITIES Table for Custom Range Entries
CREATE TABLE IF NOT EXISTS public.spot_availabilities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spot_id UUID NOT NULL REFERENCES public.parking_spots(id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    daily_start_time TIME NOT NULL DEFAULT '00:00:00',
    daily_end_time TIME NOT NULL DEFAULT '23:59:59',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.spot_availabilities
    ADD COLUMN IF NOT EXISTS spot_id UUID,
    ADD COLUMN IF NOT EXISTS start_date DATE,
    ADD COLUMN IF NOT EXISTS end_date DATE,
    ADD COLUMN IF NOT EXISTS daily_start_time TIME NOT NULL DEFAULT '00:00:00',
    ADD COLUMN IF NOT EXISTS daily_end_time TIME NOT NULL DEFAULT '23:59:59',
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- INDEXES for availability queries
CREATE INDEX IF NOT EXISTS idx_spot_availabilities_spot ON public.spot_availabilities(spot_id, start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_parking_spots_dates ON public.parking_spots(available_start_date, available_end_date);

-- Enable RLS for spot_availabilities
ALTER TABLE public.spot_availabilities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read access on spot_availabilities" ON public.spot_availabilities;
CREATE POLICY "Allow public read access on spot_availabilities"
    ON public.spot_availabilities FOR SELECT
    USING (TRUE);

DROP POLICY IF EXISTS "Allow spot owners to manage spot_availabilities" ON public.spot_availabilities;
CREATE POLICY "Allow spot owners to manage spot_availabilities"
    ON public.spot_availabilities FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.parking_spots
            WHERE id = spot_availabilities.spot_id AND owner_id = auth.uid()
        )
    );


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

-- 2. REVIEWS TABLE: Public two-way feedback after booking acceptance
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS target_user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS comment TEXT;
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS reviewee_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS review_text TEXT;
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS reviewer_role TEXT NOT NULL DEFAULT 'vehicle_owner';

ALTER TABLE public.reviews DROP CONSTRAINT IF EXISTS reviews_reviewer_role_check;

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

-- Drop single-column unique constraint on booking_id if exists to allow two-way review (one by customer, one by host)
ALTER TABLE public.reviews DROP CONSTRAINT IF EXISTS reviews_booking_id_key;
ALTER TABLE public.reviews DROP CONSTRAINT IF EXISTS reviews_booking_reviewer_unique;
ALTER TABLE public.reviews ADD CONSTRAINT reviews_booking_reviewer_unique UNIQUE (booking_id, reviewer_id);
CREATE INDEX IF NOT EXISTS idx_reviews_target_user ON public.reviews(target_user_id);
CREATE INDEX IF NOT EXISTS idx_reviews_spot_created_at ON public.reviews(spot_id, created_at DESC);

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
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public;

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

-- Account deletion, user-generated-content moderation, and public deletion requests.

CREATE TABLE IF NOT EXISTS public.deletion_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email_or_phone TEXT NOT NULL CHECK (char_length(btrim(email_or_phone)) BETWEEN 3 AND 254),
    reason TEXT NOT NULL CHECK (char_length(btrim(reason)) BETWEEN 3 AND 2000),
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'under_review', 'completed', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.deletion_requests
    ADD COLUMN IF NOT EXISTS email_or_phone TEXT,
    ADD COLUMN IF NOT EXISTS reason TEXT,
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'open',
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

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
    ADD COLUMN IF NOT EXISTS reporter_id UUID,
    ADD COLUMN IF NOT EXISTS reported_user_id UUID,
    ADD COLUMN IF NOT EXISTS spot_id UUID,
    ADD COLUMN IF NOT EXISTS review_id UUID,
    ADD COLUMN IF NOT EXISTS reason TEXT,
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'open',
    ADD COLUMN IF NOT EXISTS admin_notes TEXT,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

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

ALTER TABLE public.blocked_users
    ADD COLUMN IF NOT EXISTS blocker_id UUID,
    ADD COLUMN IF NOT EXISTS blocked_user_id UUID,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

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

-- Migration: 20261113000003_exact_listing_availability.sql
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

