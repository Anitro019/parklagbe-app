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
    requested_role := LOWER(COALESCE(NEW.raw_user_meta_data->>'account_type', 'driver'));

    -- Prevent self-assignment of admin role during sign-up metadata
    IF requested_role NOT IN ('driver', 'host') THEN
        requested_role := 'driver';
    END IF;

    INSERT INTO public.profiles (id, full_name, phone, account_type)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'ParkLagbee User'),
        NEW.phone,
        requested_role
    )
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
CREATE POLICY "Public profiles are viewable by everyone"
    ON public.profiles FOR SELECT
    USING (true);

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

DROP POLICY IF EXISTS "Reviewers can insert reviews for completed bookings" ON public.reviews;
CREATE POLICY "Reviewers can insert reviews for completed bookings"
    ON public.reviews FOR INSERT
    WITH CHECK (
        reviewer_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.bookings b
            WHERE b.id = booking_id AND b.customer_id = auth.uid() AND b.booking_status = 'completed'
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
