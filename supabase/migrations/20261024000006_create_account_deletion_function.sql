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
