## Interface Lock

**Feature**: Persist Sync Retry Counts on Entities
**Created**: 2026-01-17
**Status**: locked
**Lock Version**: v1 (increment on any contract change)
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

- New/changed model fields:
  - `TaskItem.retryCount: Int = 0` (new property)
  - `Activity.retryCount: Int = 0` (new property)
  - `Listing.retryCount: Int = 0` (new property)
- DTO/API changes: None (retryCount is local-only, not synced to Supabase)
- State/actions added: None (existing retry methods modified to use entity property)
- Migration required: Y (additive - SwiftData handles automatically with default value)

### Acceptance Criteria (3 max)

1. Retry counts persist across app restarts (entity.retryCount survives app relaunch)
2. 5-retry limit is enforced using persisted retryCount, not in-memory dictionary
3. retryCount resets to 0 when entity.syncState becomes .synced

### Non-goals (prevents scope creep)

- No changes to retry backoff timing (RetryPolicy unchanged)
- No changes to DTOs or Supabase sync (retryCount is local-only)
- No UI changes for displaying retry counts
- No changes to maxRetries constant (stays at 5)

### Compatibility Plan

- **Backward compatibility**: Existing entities get retryCount = 0 (default value)
- **Default when missing**: 0 (SwiftData default)
- **Rollback strategy**: Remove property from models; SyncManager falls back to in-memory tracking

---

### Ownership

- **feature-owner**: Add retryCount property to TaskItem, Activity, Listing; update SyncManager retry methods
- **data-integrity**: Review schema changes are additive and migration-safe

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

- [None yet - simple additive schema change]

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (no UI changes)
**Reviewed**: N/A

#### Checklist

N/A - UI Review Required: NO

#### Verdict Notes

No UI changes in this feature. Jobs Critique not required.

---

### Enforcement Summary

| Check | Enforced By | Consequence |
|-------|-------------|-------------|
| UI Review Required: NO | N/A | Jobs Critique skipped |
| Lock Version changed | all agents | Must stop and re-read contract |
| Acceptance criteria met | integrator | Required for DONE |
| Context7 Queries logged | integrator | Warning if missing (not blocking) |

---

### Files to Modify

1. `/Users/noahdeskin/conductor/workspaces/dispatch/cambridge/Dispatch/Features/WorkItems/Models/TaskItem.swift`
   - Add `var retryCount: Int = 0` near other sync properties (line ~122-124)

2. `/Users/noahdeskin/conductor/workspaces/dispatch/cambridge/Dispatch/Features/WorkItems/Models/Activity.swift`
   - Add `var retryCount: Int = 0` near other sync properties (line ~125-127)

3. `/Users/noahdeskin/conductor/workspaces/dispatch/cambridge/Dispatch/Features/Listings/Models/Listing.swift`
   - Add `var retryCount: Int = 0` near other sync properties (line ~90-92)

4. `/Users/noahdeskin/conductor/workspaces/dispatch/cambridge/Dispatch/Foundation/Persistence/Sync/SyncManager.swift`
   - Update `incrementRetry(for:)` to accept entity reference, increment entity.retryCount
   - Update `resetRetry(for:)` to set entity.retryCount = 0
   - Update `retryCount(for:)` to read from entity
   - Update `resetAllRetryCounts()` to iterate failed entities and reset their retryCount
   - Remove or deprecate in-memory `retryCountByEntity` dictionary
   - Update call sites in retryTask, retryActivity, retryListing, retryFailedEntities

### Implementation Pattern

Follow existing sync property pattern:

```swift
// In TaskItem.swift, Activity.swift, Listing.swift
// Add near syncStateRaw and lastSyncError

/// Tracks retry attempts for failed sync operations. Persisted across app restarts.
/// Reset to 0 on successful sync.
var retryCount: Int = 0
```
