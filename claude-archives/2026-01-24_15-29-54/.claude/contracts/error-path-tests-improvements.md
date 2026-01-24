## Interface Lock

**Feature**: ErrorPathTests Improvements - Retry Logic and Shared Error Helper
**Created**: 2026-01-17
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Base 2-patchset plan (no complexity indicators checked):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: New internal `userFacingMessage(for:)` function (Error extension or free function)
- Migration required: N

### Acceptance Criteria (3 max)

1. `testRetryEligible_WhenBelowMaxRetries` calls `retryTask()`, asserts `retryCount` incremented (4 -> 5), asserts `syncState` transitions to `.pending`, and verifies return value is `true`
2. Shared `userFacingMessage(for:)` function exists and is called by both SyncManager and ErrorPathTests (no duplicated logic)
3. All ErrorPathTests pass, including existing error message mapping tests

### Non-goals (prevents scope creep)

- No changes to retry policy constants or backoff algorithm
- No new error types or error codes
- No changes to other test files beyond ErrorPathTests
- No refactoring of SyncManager beyond removing the private helper

### Compatibility Plan

- **Backward compatibility**: N/A (internal refactor, no API changes)
- **Default when missing**: N/A
- **Rollback strategy**: Revert the 3 files to previous state

---

### Implementation Notes

**Task 1: Retry Logic Test Fix (lines ~148-166)**

Current test only asserts precondition:
```swift
func testRetryEligible_WhenBelowMaxRetries() async throws {
  // ... creates task with retryCount = 4 (one below max of 5)
  XCTAssertTrue(task.retryCount < RetryPolicy.maxRetries, "Precondition...")
}
```

Needs to:
1. Store initial `retryCount` (4)
2. Call `await syncManager.retryTask(task)`
3. Assert return value is `true`
4. Assert `task.retryCount == 5` (incremented)
5. Assert `task.syncState == .pending` (reset for retry)

Reference: `SyncManager.retryTask()` at lines 373-407 shows:
- Line 386: `task.retryCount += 1`
- Line 403: `task.syncState = .pending`

**Task 2: Shared userFacingMessage Helper**

Extract the duplicated logic from:
- `SyncManager.userFacingMessage(for:)` (lines 829-868, private)
- `ErrorPathTests.userFacingMessage(for:)` (lines 417-454, private)

Create shared function at: `Dispatch/Foundation/Persistence/Errors/SyncError+UserFacing.swift`

The function must handle:
- URLError codes: `.notConnectedToInternet`, `.networkConnectionLost`, `.timedOut`, other
- Postgres permission errors (42501) with table-specific messages
- Fallback for unknown errors

Make it `internal` so both SyncManager (main target) and tests can access it.

---

### Files Affected

| File | Change |
|------|--------|
| `DispatchTests/ErrorPathTests.swift` | Fix test, remove local helper |
| `Dispatch/Foundation/Persistence/Sync/SyncManager.swift` | Replace private method with shared function call |
| `Dispatch/Foundation/Persistence/Errors/SyncError+UserFacing.swift` | NEW: shared error message helper |

---

### Ownership

- **feature-owner**: Implement both changes end-to-end (test fix + shared helper extraction)
- **data-integrity**: Not needed
- **jobs-critic**: Not needed (UI Review Required: NO)

---

### Context7 Queries

Log all Context7 lookups here:

- N/A - Pure Swift refactoring, no framework/library patterns needed

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: N/A
**Libraries Queried**: N/A

| Query | Pattern Used |
|-------|--------------|
| N/A - Pure refactor | N/A |

**N/A**: Valid for pure refactors with no framework/library usage.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)
**Reviewed**: N/A

---

### Enforcement Summary

- [x] Contract locked
- [x] PATCHSET 1: Compiles (iOS + macOS verified)
- [x] PATCHSET 2: Tests pass (all 25 ErrorPathTests pass)
- [x] Integrator: DONE (re-applied after revert)
