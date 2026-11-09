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
    booking_id UUID UNIQUE NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
    reviewer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    spot_id UUID NOT NULL REFERENCES public.parking_spots(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
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
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'under_review', 'resolved', 'dismissed')),
    admin_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. ADMIN AUDIT LOGS TABLE
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL,
    target_id UUID,
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
