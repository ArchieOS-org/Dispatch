-- Multi-Assignee Migration
-- Replaces single-user claimed_by with multi-assignee join tables
-- Run this migration on Supabase after backing up data

-- ============================================================================
-- PHASE 1: Create Join Tables
-- ============================================================================

-- task_assignees join table
CREATE TABLE IF NOT EXISTS task_assignees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  assigned_by UUID NOT NULL REFERENCES users(id),
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Prevent duplicate assignments
  UNIQUE(task_id, user_id)
);

-- activity_assignees join table
CREATE TABLE IF NOT EXISTS activity_assignees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  assigned_by UUID NOT NULL REFERENCES users(id),
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Prevent duplicate assignments
  UNIQUE(activity_id, user_id)
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_task_assignees_task ON task_assignees(task_id);
CREATE INDEX IF NOT EXISTS idx_task_assignees_user ON task_assignees(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_assignees_activity ON activity_assignees(activity_id);
CREATE INDEX IF NOT EXISTS idx_activity_assignees_user ON activity_assignees(user_id);

-- ============================================================================
-- PHASE 2: Migrate Existing Data
-- ============================================================================

-- Migrate existing claimed_by data to task_assignees
INSERT INTO task_assignees (task_id, user_id, assigned_by, assigned_at)
SELECT id, claimed_by, declared_by, COALESCE(claimed_at, created_at)
FROM tasks
WHERE claimed_by IS NOT NULL
ON CONFLICT (task_id, user_id) DO NOTHING;

-- Migrate existing claimed_by data to activity_assignees
INSERT INTO activity_assignees (activity_id, user_id, assigned_by, assigned_at)
SELECT id, claimed_by, declared_by, COALESCE(claimed_at, created_at)
FROM activities
WHERE claimed_by IS NOT NULL
ON CONFLICT (activity_id, user_id) DO NOTHING;

-- ============================================================================
-- PHASE 3: Verification Queries (RUN THESE BEFORE PHASE 4!)
-- ============================================================================

-- These should return 0 rows if migration successful:

-- Check tasks migration
-- SELECT id FROM tasks
-- WHERE claimed_by IS NOT NULL
-- AND NOT EXISTS (
--   SELECT 1 FROM task_assignees WHERE task_id = tasks.id AND user_id = tasks.claimed_by
-- );

-- Check activities migration
-- SELECT id FROM activities
-- WHERE claimed_by IS NOT NULL
-- AND NOT EXISTS (
--   SELECT 1 FROM activity_assignees WHERE activity_id = activities.id AND user_id = activities.claimed_by
-- );

-- ============================================================================
-- PHASE 4: Enable RLS on Join Tables
-- ============================================================================

ALTER TABLE task_assignees ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_assignees ENABLE ROW LEVEL SECURITY;

-- task_assignees RLS policies
-- Note: assigned_by does NOT grant SELECT access (prevents data leak after losing task access)

CREATE POLICY task_assignees_select ON task_assignees FOR SELECT USING (
  user_id = auth.uid()  -- I'm assigned
  OR EXISTS (
    SELECT 1 FROM tasks t
    WHERE t.id = task_assignees.task_id
    AND (
      t.declared_by = auth.uid()
      OR EXISTS (
        SELECT 1 FROM listings l WHERE l.id = t.listing AND l.owned_by = auth.uid()
      )
    )
  )
);

CREATE POLICY task_assignees_insert ON task_assignees FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM tasks t
    WHERE t.id = task_id
    AND (
      t.declared_by = auth.uid()
      OR EXISTS (
        SELECT 1 FROM listings l WHERE l.id = t.listing AND l.owned_by = auth.uid()
      )
    )
  )
);

CREATE POLICY task_assignees_delete ON task_assignees FOR DELETE USING (
  user_id = auth.uid()  -- Unassign myself
  OR EXISTS (
    SELECT 1 FROM tasks t
    WHERE t.id = task_assignees.task_id
    AND (
      t.declared_by = auth.uid()
      OR EXISTS (
        SELECT 1 FROM listings l WHERE l.id = t.listing AND l.owned_by = auth.uid()
      )
    )
  )
);

-- activity_assignees RLS policies

CREATE POLICY activity_assignees_select ON activity_assignees FOR SELECT USING (
  user_id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM activities a
    WHERE a.id = activity_assignees.activity_id
    AND (
      a.declared_by = auth.uid()
      OR EXISTS (
        SELECT 1 FROM listings l WHERE l.id = a.listing AND l.owned_by = auth.uid()
      )
    )
  )
);

CREATE POLICY activity_assignees_insert ON activity_assignees FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM activities a
    WHERE a.id = activity_id
    AND (
      a.declared_by = auth.uid()
      OR EXISTS (
        SELECT 1 FROM listings l WHERE l.id = a.listing AND l.owned_by = auth.uid()
      )
    )
  )
);

CREATE POLICY activity_assignees_delete ON activity_assignees FOR DELETE USING (
  user_id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM activities a
    WHERE a.id = activity_assignees.activity_id
    AND (
      a.declared_by = auth.uid()
      OR EXISTS (
        SELECT 1 FROM listings l WHERE l.id = a.listing AND l.owned_by = auth.uid()
      )
    )
  )
);

-- ============================================================================
-- PHASE 5: Drop Deprecated Columns (AFTER VERIFICATION!)
-- ============================================================================

-- IMPORTANT: Only run after verifying Phase 3 queries return 0 rows!

-- ALTER TABLE tasks
--   DROP COLUMN claimed_by,
--   DROP COLUMN claimed_at,
--   DROP COLUMN priority;

-- ALTER TABLE activities
--   DROP COLUMN claimed_by,
--   DROP COLUMN claimed_at,
--   DROP COLUMN priority,
--   DROP COLUMN activity_type;

-- Drop claim_events table (no longer needed)
-- DROP TABLE IF EXISTS claim_events;

-- ============================================================================
-- ROLLBACK PLAN (if needed)
-- ============================================================================

-- If migration fails, restore from backup:
-- 1. Re-add columns:
--    ALTER TABLE tasks ADD COLUMN claimed_by UUID, ADD COLUMN claimed_at TIMESTAMPTZ;
--    ALTER TABLE activities ADD COLUMN claimed_by UUID, ADD COLUMN claimed_at TIMESTAMPTZ;
-- 2. Restore data:
--    UPDATE tasks SET claimed_by = (SELECT user_id FROM task_assignees WHERE task_id = tasks.id LIMIT 1);
--    UPDATE activities SET claimed_by = (SELECT user_id FROM activity_assignees WHERE activity_id = activities.id LIMIT 1);
-- 3. Drop join tables:
--    DROP TABLE task_assignees, activity_assignees;
