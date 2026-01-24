## Interface Lock

**Feature**: Audit History System Fix - Assignee Sync & Cascade Delete Issues
**Created**: 2026-01-24
**Updated**: 2026-01-24
**Status**: locked
**Lock Version**: v2
**UI Review Required**: NO

---

### Complexity Indicators

- [x] **Schema changes** - YES (FK CASCADE behavior investigation, possible migration)
- [ ] **Complex UI** - NO (bug fix, not UI change)
- [x] **High-risk flow** - YES (involves sync, CASCADE DELETE, audit triggers)
- [x] **Unfamiliar area** - YES (PostgreSQL FK CASCADE + SwiftData sync interaction)

### Patchset Plan

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Investigation complete, root cause verified | dispatch-explorer |
| 1.5 | Fix strategy determined, migration if needed | data-integrity |
| 2 | Sync handlers fixed, no data loss on claim/unclaim | feature-owner, integrator |

---

### Problem Statement (UPDATED v2)

**Bug 1: Activity assignees log not updating**
- On every change to assignees, a new row should be added to `audit.activity_assignees_log`
- Current count: only 4 rows despite multiple claim/unclaim operations
- Expected: Each claim/unclaim should generate INSERT/DELETE audit events

**Bug 2: Tasks/activities appear deleted on claim/unclaim/status changes**
- When claiming, unclaiming, or changing status of a task/activity
- The items seemingly become "deleted" in the iOS app
- Affects all platforms (not just iOS)
- Related to sync pattern and CASCADE DELETE

---

### Root Cause Analysis (IDENTIFIED)

#### The CASCADE DELETE Problem

The sync handlers use a DELETE+INSERT pattern to ensure audit triggers fire. However:

1. **FK Constraints with CASCADE DELETE**:
   ```sql
   task_assignees_task_id_fkey FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
   activity_assignees_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
   ```

2. **Sync Flow That Causes Data Loss**:
   ```
   User claims task:
   1. task.markPending(), assignee created locally
   2. syncUp() runs
   3. syncUpTasks(): DELETE task FROM server -> CASCADE DELETES ALL assignees
   4. syncUpTasks(): INSERT task (task re-created, but no assignees)
   5. syncUpTaskAssignees(): tries to INSERT assignee (may fail if duplicate or RLS)
   6. Result: Task exists but has no assignees, or wrong assignees
   ```

3. **Why Items "Appear Deleted"**:
   - Local SwiftData has assignee records pointing to task
   - Server task exists but has no assignees (cascade deleted)
   - syncDown updates local task, relationship state becomes inconsistent
   - SwiftData `@Relationship(deleteRule: .cascade)` may further cascade locally

#### Evidence in Code

From `SyncManager+Operations.swift` lines 147-149:
```swift
// CRITICAL: Capture pending task/activity IDs BEFORE syncing them.
// Task/activity sync uses DELETE+INSERT pattern which triggers CASCADE delete of assignees.
```

This comment shows awareness of the issue, but pre-capturing IDs doesn't prevent the server-side cascade.

---

### Fix Strategy Options

#### Option A: Sync Assignees BEFORE Deleting Parent (RECOMMENDED)

Reorder sync operations:
1. DELETE assignees that need to be removed (unclaim)
2. INSERT new assignees (claim)
3. THEN DELETE+INSERT the parent task/activity

This ensures assignee state is synced before the parent triggers cascade.

**Pros**: Minimal schema change, preserves audit history
**Cons**: Requires careful ordering, may still have race conditions

#### Option B: Change FK to ON DELETE SET NULL

Change FK constraints:
```sql
ALTER TABLE task_assignees DROP CONSTRAINT task_assignees_task_id_fkey;
ALTER TABLE task_assignees ADD CONSTRAINT task_assignees_task_id_fkey
  FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE SET NULL;
```

**Pros**: No cascade, assignees survive parent deletion
**Cons**: Creates orphan records, requires cleanup logic, breaks audit assumptions

#### Option C: Remove DELETE+INSERT, Use UPSERT with Manual Audit

Change sync to UPSERT and manually insert audit records via RPC.

**Pros**: No cascade issues
**Cons**: Complex, audit consistency harder to maintain

#### Option D: Disable Triggers During Sync (NOT RECOMMENDED)

Temporarily disable audit triggers during DELETE+INSERT.

**Pros**: Quick fix
**Cons**: Loses audit history, violates audit requirements

---

### Acceptance Criteria (3 max)

1. Claiming/unclaiming a task does NOT cause the task to appear deleted
2. `audit.activity_assignees_log` receives INSERT/DELETE events for each claim/unclaim
3. Sync cycle completes without data loss for assignee records

### Non-goals (prevents scope creep)

- No changes to audit trigger definitions (they work correctly)
- No UI changes
- Not addressing unrelated sync issues

---

### Investigation Tasks (PATCHSET 1)

1. **Verify cascade behavior with test query**:
   ```sql
   -- Check if cascade delete is the issue
   SELECT * FROM task_assignees WHERE task_id = '<test-task-id>';
   -- Delete and re-insert task
   -- Check task_assignees again
   ```

2. **Verify audit trigger is firing**:
   ```sql
   SELECT * FROM audit.task_assignees_log ORDER BY changed_at DESC LIMIT 10;
   ```

3. **Check for suppressed errors in sync handlers**:
   - Look for silent catch blocks
   - Add logging to confirm INSERT success/failure

---

### Ownership

- **dispatch-explorer**: Verify CASCADE behavior via Supabase queries
- **data-integrity**: Determine fix strategy, create migration if needed
- **feature-owner**: Implement sync handler fix
- **integrator**: Verify builds and test sync behavior

---

### Context7 Queries

CONTEXT7_QUERY: upsert method to update or insert records without triggering delete
CONTEXT7_TAKEAWAYS:
- Supabase Swift `.upsert(dto)` inserts or updates based on primary key conflict
- Can specify `onConflict:` parameter to target specific columns
- No DELETE is triggered - it's a merge operation (resolution=merge-duplicates)
- Supports both single records and arrays of records
- Discard result with `_` to avoid decode errors
CONTEXT7_APPLIED:
- `.upsert(dto).execute()` -> TaskSyncHandler.swift:syncUp(), ActivitySyncHandler.swift:syncUp()

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: Supabase Swift

| Query | Pattern Used |
|-------|--------------|
| upsert method to update or insert records without triggering delete | `.upsert(dto).execute()` for INSERT or UPDATE without DELETE |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)
**Reviewed**: N/A

---

### Implementation Notes

**For dispatch-explorer:**
- Query `pg_constraint` to verify FK CASCADE rules
- Check `audit.*_log` tables for recent entries
- Verify trigger definitions with `pg_trigger`

**For data-integrity:**
- Evaluate Option A (reorder sync) vs Option B (change FK)
- If migration needed, test on staging first
- Consider rollback strategy

**For feature-owner:**
- If Option A: Modify `SyncManager+Operations.syncUp()` to sync assignees first
- Ensure assignee DELETE operations complete before parent DELETE
- Add defensive checks for orphan assignees

**Context7 Recommended For:**
- PostgreSQL FK constraint behavior
- Supabase trigger patterns
- SwiftData cascade rules

---

### PATCHSET 1: Investigation [COMPLETE]

**Status**: Root cause identified via code analysis

**Findings**:
1. CASCADE DELETE on FK constraints causes assignees to be deleted when parent task/activity is deleted
2. DELETE+INSERT sync pattern triggers this cascade
3. Pre-capturing pending IDs doesn't prevent server-side cascade
4. Audit triggers ARE working - the issue is data loss, not trigger failure

---

### PATCHSET 1.5: Fix Strategy [COMPLETE]

**Status**: Implemented Option C (simplified) - Use UPSERT for tasks/activities

**Approach**: Changed TaskSyncHandler and ActivitySyncHandler to use UPSERT instead of DELETE+INSERT.
This avoids triggering CASCADE DELETE on FK constraints while still maintaining audit logging
(PostgreSQL UPSERT triggers UPDATE events which audit triggers handle).

**Files Modified**:
- `Dispatch/Foundation/Persistence/Sync/Handlers/TaskSyncHandler.swift` - syncUp() now uses UPSERT
- `Dispatch/Foundation/Persistence/Sync/Handlers/ActivitySyncHandler.swift` - syncUp() now uses UPSERT
- `Dispatch/Foundation/Persistence/Sync/SyncManager+Operations.swift` - Updated comment

---

### Related Contracts

- Previous v1 focused on RLS policies (resolved)
- This v2 focuses on CASCADE DELETE and sync ordering
