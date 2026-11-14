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

-- INDEXES for availability queries
CREATE INDEX IF NOT EXISTS idx_spot_availabilities_spot ON public.spot_availabilities(spot_id, start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_parking_spots_dates ON public.parking_spots(available_start_date, available_end_date);

-- Enable RLS for spot_availabilities
ALTER TABLE public.spot_availabilities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access on spot_availabilities"
    ON public.spot_availabilities FOR SELECT
    USING (TRUE);

CREATE POLICY "Allow spot owners to manage spot_availabilities"
    ON public.spot_availabilities FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.parking_spots
            WHERE id = spot_availabilities.spot_id AND owner_id = auth.uid()
        )
    );
