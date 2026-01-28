## Interface Lock

**Feature**: Sync State Loop Fix
**Created**: 2025-01-24
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [x] **High-risk flow** (adds xcode-pilot, PATCHSET 3) - sync is critical infrastructure
- [ ] **Unfamiliar area** (adds dispatch-explorer) - already explored

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |
| 3 | Validation | xcode-pilot (sync validation) |

---

### Problem Statement

Tasks get flipped back to `.pending` after being marked `.synced`, creating infinite sync loops where remote updates are perpetually skipped.

### Root Causes (Identified via Exploration)

1. **`isSyncing` flag not gating `markPending()`** - Flag exists at SyncManager.swift:116 but is not checked before marking entities pending. During sync operations, relationship mutations (e.g., assignee array modifications) trigger SwiftData dirty tracking, which calls `markPending()` even though the entity was just synced.

2. **Relationship mutations trigger dirty tracking** - Assignee operations (`append`, `delete`) on `task.assignees` array cause SwiftData to mark parent Task dirty, flipping state back to `.pending`.

3. **Finalization pass is fragile** - SyncManager+Operations.swift:173-179 workaround re-marks tasks as `.synced` after assignee sync, but only covers entities captured at sync start. Does not handle entities that become pending through other paths during sync.

4. **`isLocalAuthoritative()` ignores timestamps** - ConflictResolver.swift:167-177 skips ALL remote updates for pending entities regardless of timestamps. This means once an entity is flipped back to `.pending` erroneously, it will never accept remote updates even if remote is newer.

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: `SyncManager.isSyncingSuppressesPending` (read-only public accessor)
- Migration required: N

### Acceptance Criteria (3 max)

1. **No sync loops**: After a successful sync, entities remain `.synced` and do not flip back to `.pending` until user action
2. **Timestamp-aware conflict resolution**: Remote updates with `updatedAt > local.updatedAt` are applied even if local is `.pending` (unless local has genuine pending changes made post-sync)
3. **Finalization is robust**: All entities that were `.pending` at sync start and successfully synced remain `.synced` after all relationship operations complete

### Non-goals (prevents scope creep)

- No changes to the delta fetch logic
- No changes to realtime subscription handling
- No refactoring of SyncManager architecture
- No UI changes or error message changes

### Compatibility Plan

- **Backward compatibility**: N/A - internal sync logic only
- **Default when missing**: N/A
- **Rollback strategy**: Revert commit - no persistent schema changes

---

### Files to Modify

| File | Change |
|------|--------|
| `/Dispatch/Foundation/Persistence/Sync/SyncManager.swift` | Expose `isSyncing` via public accessor for suppression check |
| `/Dispatch/Foundation/Persistence/Sync/ConflictResolver.swift` | Add timestamp comparison to `isLocalAuthoritative()` |
| `/Dispatch/Features/WorkItems/Models/TaskItem.swift` | Gate `markPending()` with sync suppression check |
| `/Dispatch/Features/WorkItems/Models/Activity.swift` | Gate `markPending()` with sync suppression check |
| `/Dispatch/Features/Listings/Models/Listing.swift` | Gate `markPending()` with sync suppression check |
| `/Dispatch/Features/WorkItems/Models/Note.swift` | Gate `markPending()` with sync suppression check |
| `/Dispatch/Foundation/Persistence/Protocols/RealtimeSyncable.swift` | Add protocol extension helper for sync suppression |
| `/Dispatch/Foundation/Persistence/Sync/SyncManager+Operations.swift` | Strengthen finalization pass to cover edge cases |

### Implementation Notes

**Part 1: Gate `markPending()` during sync**

Add to `RealtimeSyncable` protocol extension:
```swift
/// Check if sync operations should suppress markPending() calls.
/// This prevents SwiftData dirty tracking from flipping synced entities back to pending.
var shouldSuppressPending: Bool {
  SyncManager.shared.isSyncing
}
```

Update each model's `markPending()`:
```swift
func markPending() {
  // During sync, relationship mutations trigger SwiftData dirty tracking.
  // Suppress state changes to prevent sync loops.
  guard !shouldSuppressPending else { return }
  syncState = .pending
  lastSyncError = nil
  updatedAt = Date()
}
```

**Part 2: Add timestamp comparison to `isLocalAuthoritative()`**

Current logic (too aggressive):
```swift
func isLocalAuthoritative(_ model: some RealtimeSyncable, inFlight: Bool) -> Bool {
  model.syncState == .pending || model.syncState == .failed || inFlight
}
```

Updated logic (timestamp-aware):
```swift
func isLocalAuthoritative<T: RealtimeSyncable & HasTimestamps>(
  _ model: T,
  remoteUpdatedAt: Date,
  inFlight: Bool
) -> Bool {
  // In-flight always wins (we just sent this to server)
  guard !inFlight else { return true }

  // Failed entities need retry, don't overwrite
  guard model.syncState != .failed else { return true }

  // Synced entities always accept remote updates
  guard model.syncState == .pending else { return false }

  // Pending entities: local wins only if local is newer
  return model.updatedAt > remoteUpdatedAt
}
```

**Part 3: Strengthen finalization**

The current finalization pass only covers entities captured at sync start. Need to also catch any entities that were marked pending during sync due to relationship mutations, and flip them back to `.synced` if they have no genuine local changes.

### Ownership

- **feature-owner**: End-to-end implementation of all three parts
- **data-integrity**: Not needed (no schema changes)

---

### Context7 Attestation [MANDATORY]

> **Enforcement**: Integrator BLOCKS DONE if required reports are missing or CONTEXT7 CONSULTED: NO

#### Required Libraries (filled by planner or feature-owner)

| Library | Context7 ID | Why Needed |
|---------|-------------|------------|
| Swift | /swiftlang/swift | Actor isolation, async/await patterns for sync operations |
| SwiftData | Use resolve-library-id | Dirty tracking behavior understanding |

**N/A is only valid** for pure refactors with no framework/library usage.

---

#### Agent Reports

Each agent fills their section below. **Integrator verifies these are complete before DONE.**

##### feature-owner Report (MUST FILL)

**CONTEXT7 CONSULTED**: YES

| Library | Query | Result |
|---------|-------|--------|
| Swift | nonisolated property in MainActor class accessing isolated state | nonisolated methods cannot access actor-isolated state; must use Task { @MainActor in } for async access or keep property isolated |

**CONTEXT7_APPLIED**:
- Kept `SyncManager.isSyncing` as `@MainActor` isolated
- Added `@MainActor` to `shouldSuppressPending` protocol extension in RealtimeSyncable.swift
- Added `@MainActor` to all `markPending()` implementations to access `shouldSuppressPending`
- Added `@MainActor` to `softDelete` and `undoDelete` in Note.swift since they call `markPending()`

_N/A only valid for pure refactors with zero framework code._

##### ui-polish Report (FILL IF CODE CHANGES)

**Not applicable** - No UI changes in this contract.

##### swift-debugger Report (FILL IF INVOKED)

**DEBUGGING PERFORMED**: [PENDING]

| Library | Query | Result |
|---------|-------|--------|
| | | |

_Leave empty if swift-debugger not invoked._

---

### Jobs Critique (written by jobs-critic agent)

**Not applicable** - UI Review Required: NO

---

### Test Strategy

1. **Unit tests**: Add tests for `markPending()` suppression during sync
2. **Integration tests**: Verify sync loop does not occur after successful sync with assignee modifications
3. **xcode-pilot validation**: Run sync scenario on simulator to verify no infinite loops

### Dangerous Operations

- [ ] **None** - All changes are internal sync logic, no destructive operations
