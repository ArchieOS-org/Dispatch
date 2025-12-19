-- =============================================
-- DISPATCH: Broadcast-from-Database Migration
-- Migration to postgres_changes → realtime.broadcast_changes()
--
-- This eliminates self-echo issues by including origin_user_id in payloads.
-- Run this in Supabase SQL Editor after verifying pre-flight check passes.
-- =============================================

-- =============================================
-- PRE-FLIGHT CHECK
-- Verify realtime.broadcast_changes() is available
-- =============================================
-- Run this first to confirm the function exists:
-- SELECT proname FROM pg_proc
-- WHERE proname = 'broadcast_changes'
--   AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'realtime');
-- If not found: enable realtime extension or contact Supabase support.

-- =============================================
-- MIGRATION 1: Broadcast Trigger Function
-- Generic trigger function for broadcasting table changes
-- =============================================

CREATE OR REPLACE FUNCTION public.broadcast_table_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    payload JSONB;
    old_payload JSONB;
    origin_user UUID;
    metadata JSONB;
BEGIN
    -- Get the user who initiated this change
    -- NOTE: auth.uid() will be NULL for system scripts, migrations, background jobs
    -- Client treats NULL origin as "not self" (do not skip those events)
    origin_user := auth.uid();

    -- Build metadata envelope for payload versioning
    metadata := jsonb_build_object(
        '_origin_user_id', origin_user,  -- NULL is valid (system-originated)
        '_event_version', 1              -- For future payload evolution
    );

    -- Build payloads based on operation
    IF TG_OP = 'DELETE' THEN
        payload := NULL;
        old_payload := to_jsonb(OLD) || metadata;
    ELSIF TG_OP = 'INSERT' THEN
        payload := to_jsonb(NEW) || metadata;
        old_payload := NULL;
    ELSE -- UPDATE
        payload := to_jsonb(NEW) || metadata;
        old_payload := to_jsonb(OLD);
    END IF;

    -- Broadcast the change
    PERFORM realtime.broadcast_changes(
        'dispatch:broadcast',                    -- topic (channel name)
        TG_OP,                                   -- event (INSERT/UPDATE/DELETE)
        TG_OP,                                   -- operation
        TG_TABLE_NAME,                           -- table
        TG_TABLE_SCHEMA,                         -- schema
        payload,                                 -- new record with metadata
        old_payload                              -- old record
    );

    RETURN NULL; -- AFTER trigger, return value ignored
END;
$$;

-- =============================================
-- MIGRATION 2: Per-Table Triggers
-- Create triggers for all 5 monitored tables
-- =============================================

-- Tasks
DROP TRIGGER IF EXISTS broadcast_tasks_changes ON public.tasks;
CREATE TRIGGER broadcast_tasks_changes
    AFTER INSERT OR UPDATE OR DELETE ON public.tasks
    FOR EACH ROW EXECUTE FUNCTION public.broadcast_table_changes();

-- Activities
DROP TRIGGER IF EXISTS broadcast_activities_changes ON public.activities;
CREATE TRIGGER broadcast_activities_changes
    AFTER INSERT OR UPDATE OR DELETE ON public.activities
    FOR EACH ROW EXECUTE FUNCTION public.broadcast_table_changes();

-- Listings
DROP TRIGGER IF EXISTS broadcast_listings_changes ON public.listings;
CREATE TRIGGER broadcast_listings_changes
    AFTER INSERT OR UPDATE OR DELETE ON public.listings
    FOR EACH ROW EXECUTE FUNCTION public.broadcast_table_changes();

-- Users
DROP TRIGGER IF EXISTS broadcast_users_changes ON public.users;
CREATE TRIGGER broadcast_users_changes
    AFTER INSERT OR UPDATE OR DELETE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.broadcast_table_changes();

-- ClaimEvents
DROP TRIGGER IF EXISTS broadcast_claim_events_changes ON public.claim_events;
CREATE TRIGGER broadcast_claim_events_changes
    AFTER INSERT OR UPDATE OR DELETE ON public.claim_events
    FOR EACH ROW EXECUTE FUNCTION public.broadcast_table_changes();

-- =============================================
-- MIGRATION 3: RLS Policy for Broadcast Channel
-- Allow authenticated users to receive broadcasts
-- =============================================

-- Create policy for dispatch:broadcast channel
DROP POLICY IF EXISTS "dispatch_authenticated_receive" ON realtime.messages;
CREATE POLICY "dispatch_authenticated_receive"
ON realtime.messages
FOR SELECT
TO authenticated
USING (realtime.topic() = 'dispatch:broadcast');

-- =============================================
-- VERIFICATION QUERIES (run after migration)
-- =============================================
-- 1. Verify triggers exist:
-- SELECT tgname, tgrelid::regclass, tgenabled
-- FROM pg_trigger
-- WHERE tgname LIKE 'broadcast_%';

-- 2. Verify function exists:
-- SELECT proname FROM pg_proc WHERE proname = 'broadcast_table_changes';

-- 3. Test broadcast (from authenticated client, not SQL Editor):
-- UPDATE tasks SET title = title WHERE id = (SELECT id FROM tasks LIMIT 1);
-- Client should receive broadcast event with _origin_user_id populated.

-- =============================================
-- ROLLBACK SCRIPT (if needed)
-- =============================================
-- -- Disable triggers (non-destructive)
-- ALTER TABLE public.tasks DISABLE TRIGGER broadcast_tasks_changes;
-- ALTER TABLE public.activities DISABLE TRIGGER broadcast_activities_changes;
-- ALTER TABLE public.listings DISABLE TRIGGER broadcast_listings_changes;
-- ALTER TABLE public.users DISABLE TRIGGER broadcast_users_changes;
-- ALTER TABLE public.claim_events DISABLE TRIGGER broadcast_claim_events_changes;

-- -- Full rollback (drop everything)
-- DROP TRIGGER IF EXISTS broadcast_tasks_changes ON public.tasks;
-- DROP TRIGGER IF EXISTS broadcast_activities_changes ON public.activities;
-- DROP TRIGGER IF EXISTS broadcast_listings_changes ON public.listings;
-- DROP TRIGGER IF EXISTS broadcast_users_changes ON public.users;
-- DROP TRIGGER IF EXISTS broadcast_claim_events_changes ON public.claim_events;
-- DROP FUNCTION IF EXISTS public.broadcast_table_changes();
-- DROP POLICY IF EXISTS "dispatch_authenticated_receive" ON realtime.messages;
