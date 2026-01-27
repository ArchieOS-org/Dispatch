## Interface Lock

**Feature**: Fix Sync State Persistence Bug
**Created**: 2026-01-24
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [x] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |

---

### Problem Statement

Tasks are getting stuck in "pending" sync state even after `markSynced()` is called. Root cause analysis:

1. `syncUpTasks()` upserts a task and calls `markSynced()` (line 102 in TaskSyncHandler.swift)
2. `syncUpTaskAssignees()` runs AFTER (line 169 in SyncManager+Operations.swift) and establishes relationships via `establishTaskAssigneeRelationship()`
3. When `parentTask.assignees.append(assignee)` or `assignee.task = parentTask` executes (EntitySyncHandler.swift lines 355-358), SwiftData's dirty tracking MAY flip the Task back to needing a save
4. The relationship modification does NOT call `markPending()` explicitly, but SwiftData change tracking still sees the Task as modified
5. When `context.save()` runs (SyncManager.swift line 593), the Task's `updatedAt` may have been touched by relationship establishment

**Evidence from logs**:
- "Skip update for task ... local-authoritative (state=pending)" appears at the START of the next sync cycle
- This proves the task never persisted as `.synced`, or was reverted before save

### Proposed Fix

Implement an `isSyncing` flag pattern to distinguish between user-generated mutations and sync-internal mutations:

1. **Add `syncState` property to SyncHandlerDependencies** (or pass via closure):
   - Add a way to check `isSyncing` from within sync handlers

2. **In `SyncManager.performSync()`** (lines 565-626):
   - `isSyncing` is already set to `true` at line 566
   - This flag should be exposed to handlers

3. **In relationship establishment methods** (EntitySyncHandler.swift):
   - Already guarded against in-flight conflicts via `conflictResolver`
   - Relationship changes during sync should NOT call `markPending()` (they currently don't)
   - The issue is SwiftData's internal dirty tracking, not explicit `markPending()` calls

4. **Alternative: Defer relationship establishment**:
   - Move `establishTaskAssigneeRelationship` to run BEFORE `markSynced()`
   - Or: Call `markSynced()` AFTER all relationship modifications are complete

**Recommended approach**: Option 4 - reorder operations so `markSynced()` runs AFTER relationship establishment.

### Diagnostic Logs to Add

1. **After every `markSynced()`** in TaskSyncHandler:
   ```swift
   debugLog.log("MARKSYNCED task=\(task.id) state=\(task.syncState)", category: .sync)
   ```

2. **Before final save** in SyncManager:
   ```swift
   let pendingCount = try context.fetchCount(
     FetchDescriptor<TaskItem>(predicate: #Predicate { $0.syncStateRaw == .pending })
   )
   debugLog.log("BEFORE_SAVE pendingTasks=\(pendingCount)", category: .sync)
   ```

3. **In relationship establishment**:
   ```swift
   debugLog.log("RELATIONSHIP task=\(parentTask.id) assignee=\(assignee.id) taskState=\(parentTask.syncState)", category: .sync)
   ```

---

### Contract

- New/changed model fields: None (uses existing `isSyncing` in SyncManager)
- DTO/API changes: None
- State/actions added: Expose `isSyncing` via SyncHandlerDependencies (or reorder operations)
- Migration required: N

### Acceptance Criteria (3 max)

1. Tasks marked `.synced` after `syncUpTasks()` remain `.synced` after `syncUpTaskAssignees()` completes
2. Diagnostic logs show `pendingCount=0` before final `context.save()` for tasks that were successfully synced
3. Existing sync tests continue to pass

### Non-goals (prevents scope creep)

- No changes to Activity sync (same pattern applies but address separately if needed)
- No schema changes
- No changes to realtime handlers
- No changes to conflict resolution logic

### Compatibility Plan

- **Backward compatibility**: N/A (internal fix only)
- **Default when missing**: N/A
- **Rollback strategy**: Revert changes to sync handler ordering

---

### Ownership

- **feature-owner**: Fix sync state persistence by reordering operations or exposing isSyncing flag
- **data-integrity**: Not needed (no schema changes)

---

### Files to Modify

| File | Change |
|------|--------|
| `Dispatch/Foundation/Persistence/Sync/Handlers/TaskSyncHandler.swift` | Add diagnostic logs after markSynced() |
| `Dispatch/Foundation/Persistence/Sync/SyncManager.swift` | Add diagnostic log before context.save() |
| `Dispatch/Foundation/Persistence/Sync/SyncManager+Operations.swift` | Possibly reorder operations |
| `Dispatch/Foundation/Persistence/Sync/EntitySyncHandler.swift` | Add diagnostic logs in relationship establishment |

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

- [SwiftData]: How does SwiftData dirty tracking work with relationship modifications?
- **Query executed**: "How does SwiftData track changes to relationship arrays? Does modifying a relationship like appending to an array mark the parent entity as dirty?"
- **Result**: Confirmed that SwiftData tracks relationship array modifications as changes to the parent model via `changedModelsArray`

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftData

CONTEXT7_QUERY: How does SwiftData track changes to relationship arrays? Does modifying a relationship like appending to an array mark the parent entity as dirty?
CONTEXT7_TAKEAWAYS:
- SwiftData tracks changes via `hasChanges` and `changedModelsArray` on ModelContext
- Relationship modifications (appending/removing from arrays) are tracked as changes to the parent model
- The `@Relationship` macro enables SwiftData to enforce relationships at runtime
- Inverse relationships allow bidirectional change tracking between models
CONTEXT7_APPLIED:
- Understanding that relationship array modifications mark parent as changed -> SyncManager+Operations.swift:finalizeTaskSyncState

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

(UI Review Required: NO - backend sync fix only)

---

### Investigation Notes

**Current sync flow** (from SyncManager+Operations.swift):
```
syncUp():
  1. syncUpListingTypes (admin only)
  2. syncUpActivityTemplates (admin only)
  3. capturePendingTaskIds() ← Captures IDs BEFORE sync
  4. capturePendingActivityIds()
  5. syncUpUsers
  6. syncUpProperties
  7. syncUpListings
  8. syncUpTasks ← markSynced() called here
  9. syncUpActivities
  10. syncUpTaskAssignees(taskIdsToSync: preCapturedIds) ← relationships established here
  11. syncUpActivityAssignees
  12. syncUpNotes
  13. context.save() ← Final save
```

**Hypothesis**: Even though `syncUpTaskAssignees` uses pre-captured IDs and correctly processes assignees, the `establishTaskAssigneeRelationship` function modifies the Task's `assignees` array. SwiftData's dirty tracking sees this modification and may mark the Task as needing persistence again, even though we don't explicitly call `markPending()`.

**Key code paths**:
- `TaskSyncHandler.syncUp()` line 102: `task.markSynced()` sets `syncState = .synced`
- `EntitySyncHandler.establishTaskAssigneeRelationship()` lines 355-358: modifies `parentTask.assignees` array
- SwiftData may internally track changes to relationships and mark parent entities as modified

**Potential solutions**:
1. Call `task.markSynced()` AFTER relationship establishment (requires architecture change)
2. Add a second `markSynced()` call after all relationships are established
3. Use `isSyncing` flag to prevent SwiftData from tracking relationship changes (complex)
4. Accept that Tasks may appear "modified" but ensure `syncState` is explicitly preserved

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
