-- =============================================
-- DISPATCH Phase 1.3: Development/Testing RLS Policies
-- Run this AFTER the main schema to enable unauthenticated testing
-- WARNING: Only use in development! Remove before production.
-- =============================================

-- =============================================
-- USERS TABLE - Allow anon read access
-- =============================================
DROP POLICY IF EXISTS "Anon users can read all users" ON users;
CREATE POLICY "Anon users can read all users" ON users
    FOR SELECT TO anon
    USING (true);

-- =============================================
-- LISTINGS TABLE - Allow anon full access
-- =============================================
DROP POLICY IF EXISTS "Anon listing access" ON listings;
CREATE POLICY "Anon listing access" ON listings
    FOR ALL TO anon
    USING (true)
    WITH CHECK (true);

-- =============================================
-- TASKS TABLE - Allow anon full access
-- =============================================
DROP POLICY IF EXISTS "Anon task access" ON tasks;
CREATE POLICY "Anon task access" ON tasks
    FOR ALL TO anon
    USING (true)
    WITH CHECK (true);

-- =============================================
-- ACTIVITIES TABLE - Allow anon full access
-- =============================================
DROP POLICY IF EXISTS "Anon activity access" ON activities;
CREATE POLICY "Anon activity access" ON activities
    FOR ALL TO anon
    USING (true)
    WITH CHECK (true);

-- =============================================
-- NOTES TABLE - Allow anon full access
-- =============================================
DROP POLICY IF EXISTS "Anon note access" ON notes;
CREATE POLICY "Anon note access" ON notes
    FOR ALL TO anon
    USING (true)
    WITH CHECK (true);

-- =============================================
-- SUBTASKS TABLE - Allow anon full access
-- =============================================
DROP POLICY IF EXISTS "Anon subtask access" ON subtasks;
CREATE POLICY "Anon subtask access" ON subtasks
    FOR ALL TO anon
    USING (true)
    WITH CHECK (true);

-- =============================================
-- STATUS_CHANGES TABLE - Allow anon full access
-- =============================================
DROP POLICY IF EXISTS "Anon status_change access" ON status_changes;
CREATE POLICY "Anon status_change access" ON status_changes
    FOR ALL TO anon
    USING (true)
    WITH CHECK (true);

-- =============================================
-- CLAIM_EVENTS TABLE - Allow anon full access
-- =============================================
DROP POLICY IF EXISTS "Anon claim_event access" ON claim_events;
CREATE POLICY "Anon claim_event access" ON claim_events
    FOR ALL TO anon
    USING (true)
    WITH CHECK (true);

-- =============================================
-- SYNC_METADATA TABLE - Allow anon full access
-- =============================================
DROP POLICY IF EXISTS "Anon sync_metadata access" ON sync_metadata;
CREATE POLICY "Anon sync_metadata access" ON sync_metadata
    FOR ALL TO anon
    USING (true)
    WITH CHECK (true);

-- =============================================
-- Enable Realtime for tables (if not already enabled)
-- =============================================
-- You may also need to run this in the Supabase dashboard:
-- Go to Database > Replication > supabase_realtime publication
-- Add tables: users, tasks, activities, listings

-- Alternatively, run this SQL:
ALTER PUBLICATION supabase_realtime ADD TABLE users;
ALTER PUBLICATION supabase_realtime ADD TABLE tasks;
ALTER PUBLICATION supabase_realtime ADD TABLE activities;
ALTER PUBLICATION supabase_realtime ADD TABLE listings;

-- =============================================
-- Create a test user for the app to use
-- =============================================
INSERT INTO users (id, name, email, user_type, created_at, updated_at)
VALUES (
    '00000000-0000-0000-0000-000000000001',
    'Test User',
    'test@dispatch-dev.ca',
    'admin',
    NOW(),
    NOW()
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    email = EXCLUDED.email,
    user_type = EXCLUDED.user_type,
    updated_at = NOW();

-- =============================================
-- VERIFICATION
-- =============================================
-- Run this to verify policies are in place:
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd
-- FROM pg_policies
-- WHERE schemaname = 'public'
-- ORDER BY tablename, policyname;
