-- =============================================
-- DISPATCH Phase 1.2: Complete PostgreSQL Schema
-- Run this in Supabase SQL Editor:
-- https://supabase.com/dashboard/project/uhkrvxlclflgevocqtkh/sql
-- =============================================

-- Enable UUID extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================
-- USERS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    avatar_url TEXT,
    user_type TEXT NOT NULL DEFAULT 'admin',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_user_type ON users(user_type);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read all users" ON users;
CREATE POLICY "Users can read all users" ON users
    FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Users can update own profile" ON users;
CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE TO authenticated
    USING (id = auth.uid());

-- =============================================
-- LISTINGS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS listings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    address TEXT NOT NULL,
    city TEXT DEFAULT '',
    province TEXT DEFAULT '',
    postal_code TEXT DEFAULT '',
    country TEXT DEFAULT 'Canada',
    price DECIMAL(12, 2),
    mls_number TEXT,
    listing_type TEXT DEFAULT 'sale',
    status TEXT DEFAULT 'draft',
    owned_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    assigned_staff UUID REFERENCES users(id) ON DELETE SET NULL,
    created_via TEXT DEFAULT 'dispatch',
    source_slack_messages JSONB,
    activated_at TIMESTAMPTZ,
    pending_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    due_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    synced_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_listings_owned_by ON listings(owned_by);
CREATE INDEX IF NOT EXISTS idx_listings_assigned_staff ON listings(assigned_staff);
CREATE INDEX IF NOT EXISTS idx_listings_status ON listings(status);
CREATE INDEX IF NOT EXISTS idx_listings_due_date ON listings(due_date);
CREATE INDEX IF NOT EXISTS idx_listings_updated_at ON listings(updated_at);

ALTER TABLE listings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "listing_access" ON listings;
CREATE POLICY "listing_access" ON listings FOR ALL TO authenticated
USING (
    owned_by = auth.uid()
    OR assigned_staff = auth.uid()
    OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND user_type = 'exec')
);

-- =============================================
-- TASKS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    due_date TIMESTAMPTZ,
    priority TEXT DEFAULT 'medium',
    status TEXT DEFAULT 'open',
    declared_by UUID NOT NULL REFERENCES users(id),
    claimed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    listing UUID REFERENCES listings(id) ON DELETE SET NULL,
    created_via TEXT DEFAULT 'dispatch',
    source_slack_messages JSONB,
    claimed_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    synced_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_tasks_declared_by ON tasks(declared_by);
CREATE INDEX IF NOT EXISTS idx_tasks_claimed_by ON tasks(claimed_by);
CREATE INDEX IF NOT EXISTS idx_tasks_listing ON tasks(listing);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_tasks_updated_at ON tasks(updated_at);

ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "task_access" ON tasks;
CREATE POLICY "task_access" ON tasks FOR ALL TO authenticated
USING (
    declared_by = auth.uid()
    OR claimed_by = auth.uid()
    OR listing IN (SELECT id FROM listings WHERE assigned_staff = auth.uid())
    OR listing IN (SELECT id FROM listings WHERE owned_by = auth.uid())
    OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND user_type = 'exec')
);

-- =============================================
-- ACTIVITIES TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    activity_type TEXT DEFAULT 'other',
    due_date TIMESTAMPTZ,
    priority TEXT DEFAULT 'medium',
    status TEXT DEFAULT 'open',
    duration_minutes INTEGER,
    declared_by UUID NOT NULL REFERENCES users(id),
    claimed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    listing UUID REFERENCES listings(id) ON DELETE SET NULL,
    created_via TEXT DEFAULT 'dispatch',
    source_slack_messages JSONB,
    claimed_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    synced_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_activities_declared_by ON activities(declared_by);
CREATE INDEX IF NOT EXISTS idx_activities_claimed_by ON activities(claimed_by);
CREATE INDEX IF NOT EXISTS idx_activities_listing ON activities(listing);
CREATE INDEX IF NOT EXISTS idx_activities_status ON activities(status);
CREATE INDEX IF NOT EXISTS idx_activities_due_date ON activities(due_date);
CREATE INDEX IF NOT EXISTS idx_activities_updated_at ON activities(updated_at);

ALTER TABLE activities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "activity_access" ON activities;
CREATE POLICY "activity_access" ON activities FOR ALL TO authenticated
USING (
    declared_by = auth.uid()
    OR claimed_by = auth.uid()
    OR listing IN (SELECT id FROM listings WHERE assigned_staff = auth.uid())
    OR listing IN (SELECT id FROM listings WHERE owned_by = auth.uid())
    OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND user_type = 'exec')
);

-- =============================================
-- NOTES TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content TEXT NOT NULL,
    parent_type TEXT NOT NULL,
    parent_id UUID NOT NULL,
    created_by UUID NOT NULL REFERENCES users(id),
    edited_at TIMESTAMPTZ,
    edited_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    synced_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_notes_parent ON notes(parent_type, parent_id);
CREATE INDEX IF NOT EXISTS idx_notes_created_by ON notes(created_by);
CREATE INDEX IF NOT EXISTS idx_notes_created_at ON notes(created_at DESC);

ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "note_access" ON notes;
CREATE POLICY "note_access" ON notes FOR ALL TO authenticated
USING (
    (parent_type = 'task' AND parent_id IN (SELECT id FROM tasks))
    OR (parent_type = 'activity' AND parent_id IN (SELECT id FROM activities))
    OR (parent_type = 'listing' AND parent_id IN (SELECT id FROM listings))
);

-- =============================================
-- SUBTASKS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS subtasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    parent_type TEXT NOT NULL,
    parent_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    synced_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_subtasks_parent ON subtasks(parent_type, parent_id);

ALTER TABLE subtasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "subtask_access" ON subtasks;
CREATE POLICY "subtask_access" ON subtasks FOR ALL TO authenticated
USING (
    (parent_type = 'task' AND parent_id IN (SELECT id FROM tasks))
    OR (parent_type = 'activity' AND parent_id IN (SELECT id FROM activities))
);

-- =============================================
-- STATUS_CHANGES TABLE (Audit Trail)
-- =============================================
CREATE TABLE IF NOT EXISTS status_changes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_type TEXT NOT NULL,
    parent_id UUID NOT NULL,
    old_status TEXT,
    new_status TEXT NOT NULL,
    changed_by UUID NOT NULL REFERENCES users(id),
    reason TEXT,
    changed_at TIMESTAMPTZ DEFAULT NOW(),
    synced_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_status_changes_parent ON status_changes(parent_type, parent_id);
CREATE INDEX IF NOT EXISTS idx_status_changes_changed_at ON status_changes(changed_at DESC);

ALTER TABLE status_changes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "status_change_access" ON status_changes;
CREATE POLICY "status_change_access" ON status_changes FOR ALL TO authenticated
USING (
    (parent_type = 'task' AND parent_id IN (SELECT id FROM tasks))
    OR (parent_type = 'activity' AND parent_id IN (SELECT id FROM activities))
    OR (parent_type = 'listing' AND parent_id IN (SELECT id FROM listings))
);

-- =============================================
-- CLAIM_EVENTS TABLE (Audit Trail)
-- =============================================
CREATE TABLE IF NOT EXISTS claim_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_type TEXT NOT NULL,
    parent_id UUID NOT NULL,
    action TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES users(id),
    reason TEXT,
    performed_at TIMESTAMPTZ DEFAULT NOW(),
    synced_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_claim_events_parent ON claim_events(parent_type, parent_id);
CREATE INDEX IF NOT EXISTS idx_claim_events_user ON claim_events(user_id);
CREATE INDEX IF NOT EXISTS idx_claim_events_performed_at ON claim_events(performed_at DESC);

ALTER TABLE claim_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "claim_event_access" ON claim_events;
CREATE POLICY "claim_event_access" ON claim_events FOR ALL TO authenticated
USING (
    (parent_type = 'task' AND parent_id IN (SELECT id FROM tasks))
    OR (parent_type = 'activity' AND parent_id IN (SELECT id FROM activities))
);

-- =============================================
-- SYNC_METADATA TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS sync_metadata (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    last_sync_tasks TIMESTAMPTZ DEFAULT NOW(),
    last_sync_activities TIMESTAMPTZ DEFAULT NOW(),
    last_sync_listings TIMESTAMPTZ DEFAULT NOW(),
    last_sync_notes TIMESTAMPTZ DEFAULT NOW(),
    last_sync_subtasks TIMESTAMPTZ DEFAULT NOW(),
    last_sync_status_changes TIMESTAMPTZ DEFAULT NOW(),
    last_sync_claim_events TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE sync_metadata ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "sync_metadata_access" ON sync_metadata;
CREATE POLICY "sync_metadata_access" ON sync_metadata FOR ALL TO authenticated
USING (user_id = auth.uid());

-- =============================================
-- UPDATED_AT TRIGGER FUNCTION
-- =============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers (drop first if they exist)
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_listings_updated_at ON listings;
CREATE TRIGGER update_listings_updated_at
    BEFORE UPDATE ON listings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_tasks_updated_at ON tasks;
CREATE TRIGGER update_tasks_updated_at
    BEFORE UPDATE ON tasks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_activities_updated_at ON activities;
CREATE TRIGGER update_activities_updated_at
    BEFORE UPDATE ON activities
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_sync_metadata_updated_at ON sync_metadata;
CREATE TRIGGER update_sync_metadata_updated_at
    BEFORE UPDATE ON sync_metadata
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- REPLICA IDENTITY FULL (Required for Realtime)
-- PostgreSQL needs this to emit full row data with change events
-- =============================================
ALTER TABLE users REPLICA IDENTITY FULL;
ALTER TABLE tasks REPLICA IDENTITY FULL;
ALTER TABLE activities REPLICA IDENTITY FULL;
ALTER TABLE listings REPLICA IDENTITY FULL;

-- =============================================
-- VERIFICATION QUERY (run separately after)
-- =============================================
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';
