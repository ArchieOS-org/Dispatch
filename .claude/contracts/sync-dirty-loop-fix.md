## Interface Lock

**Feature**: Sync Dirty Loop Fix
**Created**: 2025-01-24
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [x] **High-risk flow** (adds xcode-pilot, PATCHSET 3) - Sync system is critical infrastructure
- [ ] **Unfamiliar area** (adds dispatch-explorer) - Already explored in problem analysis

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Diagnostic logging compiles | feature-owner |
| 2 | Root cause identified, fix implemented, tests pass | feature-owner, integrator |
| 3 | Validation via extended sync testing | integrator (no xcode-pilot - no UI) |

---

### Problem Statement

Tasks are being marked `.pending` repeatedly every sync cycle, causing `updatedAt` to bump locally, which makes conflict resolution skip remote updates. This creates an infinite sync loop.

**Smoking gun log**: `[SyncDown] Skip update ... local-authoritative (state=pending, local=21:08:36, remote=21:08:28)`

### Root Cause Hypothesis

The `shouldSuppressPending` guard in `RealtimeSyncable.swift` (line 46-48) checks `SyncManager.shared.isSyncing`. This should prevent `markPending()` from executing during sync operations.

**Possible failure modes**:
1. **Async gaps**: Code that runs in `Task {}` blocks after `isSyncing = false` but still during sync-related operations
2. **Audit history restoration**: Branch `nsd97/audit-history-restore` may have code paths that call `markPending()` during sync
3. **SwiftData dirty tracking**: Direct property mutations (not via `markPending()`) that set `updatedAt`
4. **Finalization pass escape**: Tasks/activities finalized in `finalizeTaskSyncState` but then modified again

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: Diagnostic logging (temporary), potential guard refinements
- Migration required: N

### Acceptance Criteria (3 max)

1. **No sync loops**: After fix, running sync 5 consecutive times produces zero "FINALIZE_SYNCED" log entries (entities stay synced)
2. **Logging identifies culprit**: Diagnostic logging produces stack traces showing exactly what calls `markPending()` during sync
3. **Guard coverage verified**: All code paths that could call `markPending()` are gated by `shouldSuppressPending`

### Non-goals (prevents scope creep)

- No changes to conflict resolution strategy (already timestamp-aware)
- No refactoring of SyncManager structure
- No changes to the finalization pass architecture
- Not fixing unrelated sync issues discovered during investigation

### Compatibility Plan

- **Backward compatibility**: N/A - no API/schema changes
- **Default when missing**: N/A
- **Rollback strategy**: Revert commit; logging changes are safe to leave in DEBUG builds

---

### Investigation Plan

#### Step 1: Add Diagnostic Logging (PATCHSET 1)

Add logging to `markPending()` implementations to capture:
- When `markPending()` is called
- Whether `shouldSuppressPending` returned true (suppressed) or false (executed)
- Call stack context (using Thread.callStackSymbols in DEBUG)
- Current `isSyncing` state at moment of call

**Files to instrument**:
- `/Dispatch/Features/WorkItems/Models/TaskItem.swift` (line 184)
- `/Dispatch/Features/WorkItems/Models/Activity.swift` (line 189)
- `/Dispatch/Features/Listings/Models/Listing.swift` (line 151)
- `/Dispatch/Features/Properties/Models/Property.swift` (line 107)

**Also check for direct `updatedAt` mutations**:
- Any code that sets `updatedAt = Date()` directly (not via `markPending()`)

#### Step 2: Identify Async Timing Gaps

Check the sync flow in `SyncManager.swift`:
- Line 566: `isSyncing = true`
- Line 636: `isSyncing = false`

Verify no async operations (Task blocks, await calls) run AFTER line 636 that could trigger `markPending()`.

#### Step 3: Check Audit History Code Path

Branch `nsd97/audit-history-restore` context:
- Does `AuditSyncHandler.restoreEntity()` trigger any local model updates that call `markPending()`?
- Does syncing restored entities properly set sync state without calling `markPending()`?

#### Step 4: Verify Finalization Pass Coverage

In `SyncManager+Operations.swift`:
- `finalizeTaskSyncState` (line 220-241)
- `finalizeActivitySyncState` (line 245-266)
- `finalizeListingSyncState` (line 275-300)

Are there code paths after these that could flip entities back to pending?

---

### Key Files Reference

| File | Line(s) | Purpose |
|------|---------|---------|
| `RealtimeSyncable.swift` | 46-48 | `shouldSuppressPending` guard |
| `SyncManager.swift` | 566, 636 | `isSyncing` flag set/clear |
| `SyncManager+Operations.swift` | 220-300 | Finalization passes |
| `ConflictResolver.swift` | 203-220 | `isLocalAuthoritative()` timestamp logic |
| `TaskItem.swift` | 184-189 | `markPending()` implementation |
| `Activity.swift` | 189+ | `markPending()` implementation |
| `Listing.swift` | 151+ | `markPending()` implementation |

### Ownership

- **feature-owner**: Investigate and fix sync dirty loop - add diagnostic logging, identify root cause, implement fix
- **data-integrity**: Not needed (no schema changes)

---

### Context7 Attestation [MANDATORY]

> **Enforcement**: Integrator BLOCKS DONE if required reports are missing or CONTEXT7 CONSULTED: NO

#### Required Libraries (filled by planner or feature-owner)

| Library | Context7 ID | Why Needed |
|---------|-------------|------------|
| Swift | /swiftlang/swift | Task/async patterns, MainActor isolation |
| SwiftData | resolve-library-id first | Dirty tracking behavior, @Model property observation |

**Note**: This is primarily a debugging/investigation task. Context7 may be N/A if fix is purely guard logic without new framework code.

---

#### Agent Reports

Each agent fills their section below. **Integrator verifies these are complete before DONE.**

##### feature-owner Report (MUST FILL)

**CONTEXT7 CONSULTED**: YES

| Library | Query | Result |
|---------|-------|--------|
| Supabase Swift | fetch single row by ID using select and eq filter | Use `.eq("id", value: entityId).single().execute().value` pattern |

**PATCHSET 1 Investigation Findings**:

1. **Diagnostic Logging Added**: Added to `markPending()` in TaskItem, Activity, Listing, and Property models. Logs capture:
   - Entity type and ID
   - `isSyncing` state at call time
   - Whether call was suppressed
   - Stack trace (first 10 frames) when executed

2. **Direct updatedAt Mutations Found**: Sync handlers correctly set `existing.updatedAt = dto.updatedAt` (server timestamp) during syncDown, followed by `markSynced()`. This is correct behavior.

3. **Potential Concern Identified**: `reconcileLegacyLocalUsers()` in UserSyncHandler.swift (lines 241, 263) calls `markPending()` during syncUp() (line 132 of SyncManager+Operations.swift). However, User.markPending() has the guard, so should be suppressed.

4. **Audit History Review**: `AuditSyncHandler.restoreEntity()` only makes RPC calls to Supabase - it does NOT modify local models or call `markPending()`. Restored entities will be synced down on next sync.

5. **Async Timing Analysis**: `isSyncing = false` is set on line 636 of SyncManager.sync(), and only the `while runAgain` loop continues after that. No async operations run after isSyncing is cleared within the do-catch block.

6. **Files Modified**:
   - `/Dispatch/Features/WorkItems/Models/TaskItem.swift` - markPending() logging
   - `/Dispatch/Features/WorkItems/Models/Activity.swift` - markPending() logging
   - `/Dispatch/Features/Listings/Models/Listing.swift` - markPending() logging
   - `/Dispatch/Features/Properties/Models/Property.swift` - markPending() logging

**PATCHSET 2 Root Cause & Fix**:

**Root Cause Confirmed**: The audit history restore feature in `RecentlyDeletedView.restoreEntry()`:
1. Calls RPC to restore entity on server (sets `deleted_at = NULL`, `updated_at = NOW()`)
2. **BUG**: Does NOT insert the restored entity into local SwiftData
3. Next sync: Reconciliation pass finds the entity on server but not locally
4. Timestamp precision issue: Server `updated_at >= lastSyncTime` -> appears "newer" each sync -> re-fetched each cycle -> sync loop

**Fix Implemented**: After restore RPC succeeds, immediately fetch the restored entity from Supabase and insert it into local SwiftData with `markSynced()`. This ensures:
- Entity exists locally before next sync cycle
- Proper sync state (`syncState = .synced`) prevents reconciliation from treating it as new
- No timestamp precision issues since entity is already in sync

**Files Modified**:
- `/Dispatch/Features/History/RecentlyDeletedView.swift`:
  - Added `import SwiftData`
  - Added `@Environment(\.modelContext) private var modelContext`
  - Added `fetchAndInsertRestoredEntity()` method to fetch and insert restored entities
  - Updated `restoreEntry()` to call `fetchAndInsertRestoredEntity()` after RPC succeeds

**Context7 Applied**:
- Supabase `.eq().single()` pattern -> RecentlyDeletedView.swift:fetchAndInsertRestoredEntity (lines 229-277)

**Build Status**: iOS and macOS builds pass

##### ui-polish Report (FILL IF CODE CHANGES)

**CODE CHANGES MADE**: NO (no UI changes in this fix)

_N/A - no UI work required._

##### swift-debugger Report (FILL IF INVOKED)

**DEBUGGING PERFORMED**: [YES | NO]

| Library | Query | Result |
|---------|-------|--------|
| | | |

_To be filled if swift-debugger is invoked for framework-level debugging._

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

_Not required - UI Review Required: NO_

---

### Dangerous Ops

- [ ] None - this is investigation and bug fix, no destructive operations

### Risk Assessment

| Risk | Mitigation |
|------|------------|
| Fix could break legitimate pending state | Test that user-initiated changes still mark entities pending correctly |
| Diagnostic logging too verbose | Use DEBUG-only logging, remove or reduce after fix verified |
| Async gap fix could introduce race conditions | Use MainActor isolation consistently, verify isSyncing state atomically |

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE

**Context7 Attestation [MANDATORY]**:
- Integrator MUST verify each agent's Context7 report is filled:
  - **feature-owner**: MUST have report with `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors)
  - **ui-polish**: MUST have report if `CODE CHANGES MADE: YES`
  - **swift-debugger**: MUST have report if `DEBUGGING PERFORMED: YES`
- If any required report is missing or shows `CONTEXT7 CONSULTED: NO` -> integrator MUST reject DONE
- `N/A` is only valid for pure refactors with zero framework/library code
