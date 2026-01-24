## Interface Lock

**Feature**: Sync System Fixes (Assignee Dedup, Delta Fetch, Duplicate Logging)
**Created**: 2026-01-24
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [x] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 1.5 | Schema ready | data-integrity |
| 2 | Tests pass, criteria met | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None (internal sync logic only)
- State/actions added: None
- Migration required: Y (verify/enforce UNIQUE constraint on task_assignees)

### Workstreams

This contract has 3 independent workstreams that can be parallelized:

| Workstream | Issue | Affected Files | Dependencies |
|------------|-------|----------------|--------------|
| WS1 | TaskAssignees Duplicate Explosion | TaskSyncHandler.swift, ActivitySyncHandler.swift | WS1.5 (schema) |
| WS1.5 | DB Constraint Verification | Supabase schema | None (can run first) |
| WS2 | syncDown Delta Fetch Returns 0 | SyncManager+Operations.swift | None |
| WS3 | Duplicate Logging | DebugLogger.swift | None |

### Workstream Details

#### WS1: TaskAssignees Duplicate Explosion

**Problem**: Multiple local assignees exist for the same (task_id, user_id). The `syncUpTaskAssignees` method loops through duplicates, doing delete+insert 5x for the same composite key, causing thrash and inconsistent state.

**Root Cause Analysis**:
- Current code in `TaskSyncHandler.swift:391-421` iterates over `localIds` (assignee IDs)
- If multiple local records have same (task_id, user_id), each triggers delete+insert
- The code comments at line 326 acknowledge: "The database constraint is UNIQUE(task_id, user_id), not on assignee ID"

**Required Fix**:
1. Add local deduplication BEFORE sync: group by (task_id, user_id), keep newest, delete rest
2. Change syncUp to use UPSERT ON CONFLICT(task_id, user_id) instead of delete+insert
3. Compute desired assignee set once per task, not per duplicate local record

**Files**:
- `/Users/noahdeskin/conductor/workspaces/dispatch/salvador/Dispatch/Foundation/Persistence/Sync/Handlers/TaskSyncHandler.swift` - lines 269-425
- `/Users/noahdeskin/conductor/workspaces/dispatch/salvador/Dispatch/Foundation/Persistence/Sync/Handlers/ActivitySyncHandler.swift` - lines 273-430 (same pattern)

#### WS1.5: DB Constraint Verification (data-integrity)

**Problem**: Need to verify UNIQUE(task_id, user_id) constraint exists and is enforced on task_assignees and activity_assignees tables.

**Evidence**: Migration file at `supabase/migrations/20251201000000_remote_schema.sql:854` shows:
```sql
ADD CONSTRAINT "task_assignees_task_id_user_id_key" UNIQUE ("task_id", "user_id");
```

**Required Actions**:
1. Verify constraint exists in production Supabase
2. Verify activity_assignees has equivalent constraint
3. If missing, create migration to add it
4. Confirm ON CONFLICT behavior with UPSERT

#### WS2: syncDown Delta Fetch Returns 0

**Problem**: `syncDown` fetches 0 entities when remote clearly has data. Reconcile shows remote totals (e.g., "Remote tasks: 4") but delta fetch returns nothing.

**Root Cause Analysis**:
- Current code at `SyncManager+Operations.swift:21-23`:
  ```swift
  let lastSync = lastSyncTime ?? Date.distantPast
  let lastSyncISO = ISO8601DateFormatter().string(from: lastSync)
  ```
- Delta queries use `.gt("updated_at", value: since)` (strictly greater than)
- `lastSyncTime` is updated at `SyncManager.swift:597` AFTER sync completes
- **Issue**: If a record's `updated_at` exactly matches `lastSyncTime`, it will be skipped on next sync

**Required Fix**:
1. Change `.gt("updated_at", value: since)` to `.gte("updated_at", value: since)` OR
2. Subtract a small buffer (e.g., 1 second) from lastSyncTime before querying
3. Ensure lastSyncTime is captured BEFORE queries begin, not after

**Files**:
- `/Users/noahdeskin/conductor/workspaces/dispatch/salvador/Dispatch/Foundation/Persistence/Sync/SyncManager+Operations.swift` - lines 20-119
- `/Users/noahdeskin/conductor/workspaces/dispatch/salvador/Dispatch/Foundation/Persistence/Sync/SyncManager.swift` - lines 596-597

**Note**: ActivitySyncHandler already uses `.gte()` at line 499 for activity_templates. Standardize this pattern.

#### WS3: Duplicate Logging

**Problem**: Every log line prints twice.

**Root Cause Analysis**:
Looking at `DebugLogger.swift:77-90`:
```swift
let logLine = "[\(timestamp)] [\(category.emoji) \(category.rawValue)] \(message)"
consoleLog.debug("\(logLine)")  // <-- First log (Logger to Console)

// Also log to os_log for Console.app filtering
switch category {
case .sync: syncLog.debug("\(message)")  // <-- Second log (another Logger)
...
}
```

The issue is that BOTH `consoleLog.debug()` AND the category-specific logger (e.g., `syncLog.debug()`) are called. Both end up in Console, creating duplicates.

**Required Fix**:
Remove one of the logging sinks. Options:
1. Remove `consoleLog.debug()` call and keep category-specific loggers, OR
2. Remove category-specific logger calls and keep only `consoleLog`

Recommendation: Remove category-specific loggers (lines 82-90) since `consoleLog` already includes category in the message.

**Files**:
- `/Users/noahdeskin/conductor/workspaces/dispatch/salvador/Dispatch/Debug/DebugLogger.swift` - lines 77-91

---

### Acceptance Criteria (3 max)

1. **WS1+WS1.5**: TaskAssignee sync processes each (task_id, user_id) pair exactly once per sync cycle, regardless of duplicate local records
2. **WS2**: Delta syncDown fetches all records updated since last sync (verified by log output showing non-zero fetch counts when remote has new data)
3. **WS3**: Each debug log message appears exactly once in Console output

### Non-goals (prevents scope creep)

- No refactoring of sync architecture beyond these fixes
- No changes to realtime subscription handling
- No changes to conflict resolution logic
- No new sync status UI

### Compatibility Plan

- **Backward compatibility**: All changes are internal sync logic; no DTO or API changes
- **Default when missing**: N/A
- **Rollback strategy**: Revert Swift code changes; DB constraint is additive-only

---

### Ownership

- **feature-owner**: All Swift code changes across WS1, WS2, WS3
- **data-integrity**: WS1.5 - verify/add DB constraints, confirm UPSERT ON CONFLICT behavior

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

- [pending implementation]

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: PENDING
**Libraries Queried**: [to be filled]

| Query | Pattern Used |
|-------|--------------|
| [to be filled] | [to be filled] |

---

### Implementation Notes

#### WS1 Implementation Approach

```swift
// BEFORE (problematic):
for assigneeId in localIds {
  // Each assignee ID triggers delete+insert, even if same (task_id, user_id)
}

// AFTER (correct):
// 1. Deduplicate locally: group by (task_id, user_id), keep newest by updatedAt
// 2. Use UPSERT with ON CONFLICT (task_id, user_id) DO UPDATE
// 3. Process only deduplicated set
```

#### WS2 Implementation Approach

```swift
// BEFORE (problematic):
.gt("updated_at", value: since)  // Misses records with exact timestamp match

// AFTER (correct):
let safeLastSync = lastSync.addingTimeInterval(-1)  // 1-second buffer
.gte("updated_at", value: safeLastSyncISO)  // Use >= with buffer
```

This pattern is already used in `ActivitySyncHandler.syncDownActivityTemplates()` at lines 491-493.

#### WS3 Implementation Approach

```swift
// BEFORE (duplicate):
consoleLog.debug("\(logLine)")
switch category {
case .sync: syncLog.debug("\(message)")
...
}

// AFTER (single):
consoleLog.debug("\(logLine)")
// Remove the switch block entirely - category is already in logLine
```

---

### DAG (Task Graph)

```
WS1.5 (data-integrity) ──┐
                         ├──> WS1 (feature-owner) ──┐
WS2 (feature-owner) ─────┤                          ├──> integrator
WS3 (feature-owner) ─────┴──────────────────────────┘
```

- WS1.5 runs first (or parallel with WS2/WS3)
- WS1 depends on WS1.5 (needs confirmed constraint for UPSERT strategy)
- WS2 and WS3 are fully independent
- Integrator runs after all workstreams complete

---

### Dangerous Operations

None. All changes are:
- Additive DB constraints (if needed)
- Internal sync logic changes
- Logging changes (DEBUG-only code)

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
