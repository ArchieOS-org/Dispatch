## Interface Lock

**Feature**: Assignee RLS Policy Fix
**Created**: 2026-01-24
**Status**: in_progress
**Lock Version**: v1
**UI Review Required**: NO

---

### Complexity Indicators

- [x] **Schema changes** - YES (RLS policy updates)
- [ ] **Complex UI** - NO
- [ ] **High-risk flow** - NO
- [ ] **Unfamiliar area** - NO

### Patchset Plan

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | RLS policy fixed | data-integrity |
| 2 | Verification | integrator |

---

### Problem Statement

Assignee sync failing with "Permission denied" errors:
```
Failed to sync assignee: Permission denied during sync.
```

Flow:
1. User tries to claim task/activity (add themselves as assignee)
2. DELETE+INSERT sync pattern deletes old assignees
3. INSERT of new assignees fails due to RLS
4. Assignees are lost, tasks appear unclaimed

### Root Cause

Current RLS INSERT policy on `task_assignees` and `activity_assignees`:

```sql
EXISTS (
  SELECT 1 FROM tasks t
  WHERE t.id = task_assignees.task_id
  AND (
    t.declared_by = auth.uid()  -- task creator
    OR EXISTS (
      SELECT 1 FROM listings l
      WHERE l.id = t.listing AND l.owned_by = auth.uid()  -- listing owner
    )
  )
)
```

**Missing**: Users can't add THEMSELVES as assignees (claiming).

When user A creates a task and user B tries to claim it:
- User B is NOT the task creator (`declared_by`)
- User B is NOT the listing owner (`owned_by`)
- INSERT is denied

### Fix

Update RLS INSERT policies to allow users to add themselves:

```sql
-- task_assignees_insert (updated)
user_id = auth.uid()  -- User can add THEMSELVES as assignee
OR EXISTS (
  SELECT 1 FROM tasks t
  WHERE t.id = task_assignees.task_id
  AND (
    t.declared_by = auth.uid()  -- Task creator can add ANYONE
    OR EXISTS (
      SELECT 1 FROM listings l
      WHERE l.id = t.listing AND l.owned_by = auth.uid()  -- Listing owner can add ANYONE
    )
  )
)
```

Same pattern for `activity_assignees_insert`.

---

### Acceptance Criteria

1. Users can claim tasks/activities they didn't create
2. Assignee sync completes without permission errors
3. Existing authorization (creator/owner can add anyone) preserved

---

### Context7 Queries

CONTEXT7_QUERY: RLS policy ALTER POLICY or DROP CREATE POLICY syntax for updating existing policies
CONTEXT7_TAKEAWAYS:
- Use DROP POLICY then CREATE POLICY to update existing policies (no ALTER POLICY in Supabase)
- INSERT policies use WITH CHECK clause (not USING)
- Use (select auth.uid()) pattern for auth checks
- Policies can combine conditions with OR for multiple authorization paths
CONTEXT7_APPLIED:
- WITH CHECK clause for INSERT -> migration fix_assignee_insert_rls_policies

---

### PATCHSET 1: RLS Policy Fixed [COMPLETE]

**Migration Applied**: `fix_assignee_insert_rls_policies`

**SQL Executed**:
```sql
-- Fix RLS INSERT policies to allow users to claim tasks/activities
-- Problem: Users could only be added as assignees by task creators or listing owners
-- Solution: Allow users to add THEMSELVES as assignees (claiming)

-- Fix task_assignees INSERT policy
DROP POLICY IF EXISTS task_assignees_insert ON task_assignees;

CREATE POLICY task_assignees_insert ON task_assignees
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- User can add THEMSELVES as assignee (claiming)
    user_id = (SELECT auth.uid())
    OR
    -- Task creator or listing owner can add ANYONE
    EXISTS (
      SELECT 1 FROM tasks t
      WHERE t.id = task_assignees.task_id
      AND (
        t.declared_by = (SELECT auth.uid())
        OR EXISTS (
          SELECT 1 FROM listings l
          WHERE l.id = t.listing AND l.owned_by = (SELECT auth.uid())
        )
      )
    )
  );

-- Fix activity_assignees INSERT policy
DROP POLICY IF EXISTS activity_assignees_insert ON activity_assignees;

CREATE POLICY activity_assignees_insert ON activity_assignees
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- User can add THEMSELVES as assignee (claiming)
    user_id = (SELECT auth.uid())
    OR
    -- Activity creator or listing owner can add ANYONE
    EXISTS (
      SELECT 1 FROM activities a
      WHERE a.id = activity_assignees.activity_id
      AND (
        a.declared_by = (SELECT auth.uid())
        OR EXISTS (
          SELECT 1 FROM listings l
          WHERE l.id = a.listing AND l.owned_by = (SELECT auth.uid())
        )
      )
    )
  );
```

**Verification**: Policies confirmed updated via pg_policies query.

---
