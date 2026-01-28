## Interface Lock

**Feature**: Fix Flaky Async Tests
**Created**: 2025-01-19
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
| 2 | Tests pass deterministically (no flakes) | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None (may add test utilities)
- Migration required: N

### Acceptance Criteria (3 max)

1. All listed flaky tests pass 100% of the time on first run (no retry needed)
2. Tests use deterministic patterns (XCTestExpectation, continuations, or injectable clocks) instead of arbitrary `Task.sleep` delays
3. Total test suite execution time does not increase by more than 10%

### Non-goals (prevents scope creep)

- No changes to production code (only test files and test utilities)
- No new test coverage beyond fixing existing flaky tests
- No refactoring of non-flaky tests

### Compatibility Plan

- **Backward compatibility**: N/A (test-only changes)
- **Default when missing**: N/A
- **Rollback strategy**: Revert commits; no production impact

---

### Ownership

- **feature-owner**: Fix all flaky tests using deterministic async patterns
- **data-integrity**: Not needed

---

### Flaky Tests Analysis

#### Category 1: Task.sleep Race Conditions

**Files affected:**
- `DispatchTests/SyncQueueTests.swift` (lines 68, 90, 96, 116, 146, 167, 176)
- `DispatchTests/SyncCoalescingTests.swift` (line 44)
- `DispatchTests/AuthManagerTests.swift` (lines 272, 551)
- `DispatchTests/Persistence/Sync/RealtimeRetryTests.swift` (lines 261, 281, 288)

**Pattern:** Tests use `Task.sleep(nanoseconds:)` to wait for async operations, which is non-deterministic.

**Fix approach:**
- Replace `Task.sleep` with XCTestExpectation and `fulfillment(of:timeout:)`
- Use continuations where state changes need to be awaited
- Consider injectable `Clock` protocol for time-sensitive tests

#### Category 2: State Observation Timing

**Files affected:**
- `DispatchTests/Foundation/Persistence/Sync/CircuitBreakerTests.swift` (state change callback tests)
- `DispatchTests/ChannelLifecycleConcurrencyTests.swift` (MainActor isolation tests)
- `DispatchTests/Sync/RealtimeManagerTests.swift` (ChannelLifecycleManagerTests)

**Pattern:** Tests assert state changes without proper synchronization.

**Fix approach:**
- Use proper async/await for state transitions
- Ensure MainActor-isolated properties are accessed correctly
- Add explicit continuation-based waiting for callbacks

#### Category 3: Combine Publisher Propagation

**Files affected:**
- `DispatchTests/Persistence/Sync/RealtimeRetryTests.swift` (SyncCoordinatorRealtimeTests)

**Pattern:** Tests rely on `Task.sleep(for: .milliseconds(50))` to wait for Combine publishers to propagate.

**Fix approach:**
- Use `sink` with XCTestExpectation to wait for actual value changes
- Or use `values` property with async/await iteration

#### Category 4: SwiftData Context Timing

**Files affected:**
- `DispatchTests/SyncRelationshipTests.swift` (all test* methods)

**Pattern:** Tests may have race conditions with ModelContext operations.

**Fix approach:**
- Ensure all context operations complete before assertions
- Use proper async/await for reconciliation methods

---

### Implementation Notes

#### Recommended Utilities to Create

1. **AsyncTestHelpers.swift** - Shared test utilities:
   ```swift
   extension XCTestCase {
     /// Wait for a condition to become true with proper async handling
     func waitForCondition(
       timeout: TimeInterval = 2.0,
       condition: @escaping () async -> Bool
     ) async throws {
       let expectation = XCTestExpectation(description: "Condition met")
       Task {
         while !(await condition()) {
           await Task.yield()
         }
         expectation.fulfill()
       }
       await fulfillment(of: [expectation], timeout: timeout)
     }
   }
   ```

2. **TestClock protocol** (optional, for time-sensitive tests):
   ```swift
   protocol TestClock: Clock where Duration == Swift.Duration {
     func advance(by duration: Duration) async
   }
   ```

#### Context7 Queries to Make

- Swift Concurrency: "XCTest async await best practices deterministic testing"
- Swift: "Clock protocol injectable time testing"
- SwiftUI: "Combine publisher testing XCTestExpectation"

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: XCTest async await XCTestExpectation fulfillment deterministic testing patterns
CONTEXT7_TAKEAWAYS:
- Use `withCheckedContinuation` or `withUnsafeContinuation` for callback-based async waiting
- Avoid arbitrary sleeps; instead wait for actual state changes
- Use polling with short intervals when waiting for conditions
CONTEXT7_APPLIED:
- waitForCondition helper pattern -> AsyncTestHelpers.swift

CONTEXT7_QUERY: withCheckedContinuation continuation-based async testing callback waiting
CONTEXT7_TAKEAWAYS:
- Continuations bridge callback-based APIs to async/await
- Must resume exactly once per continuation
- Use for deterministic waiting in tests instead of arbitrary sleeps
CONTEXT7_APPLIED:
- Condition polling pattern -> SyncQueueTests.swift, SyncCoalescingTests.swift

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: Swift (/swiftlang/swift)

| Query | Pattern Used |
|-------|--------------|
| XCTest async await XCTestExpectation fulfillment deterministic testing | Polling with short intervals for condition waiting |
| withCheckedContinuation callback waiting | waitForCondition helper with timeout + polling |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)
**Reviewed**: N/A

---

### Enforcement Summary

| Check | Required | Status |
|-------|----------|--------|
| UI Review | NO | N/A |
| Context7 Attestation | YES | DONE |
| Builds (iOS + macOS) | YES | PASS |
| Tests Pass | YES | PASS |
| No New Flakes | YES | PASS |

---

### Files to Modify

1. `DispatchTests/SyncQueueTests.swift`
2. `DispatchTests/SyncCoalescingTests.swift`
3. `DispatchTests/AuthManagerTests.swift`
4. `DispatchTests/Foundation/Persistence/Sync/CircuitBreakerTests.swift`
5. `DispatchTests/ChannelLifecycleConcurrencyTests.swift`
6. `DispatchTests/Sync/RealtimeManagerTests.swift`
7. `DispatchTests/Persistence/Sync/RealtimeRetryTests.swift`
8. `DispatchTests/SyncRelationshipTests.swift`
9. (NEW) `DispatchTests/Utilities/AsyncTestHelpers.swift` (optional shared utilities)

---

### Verification Checklist

- [x] Run each flaky test 10 times consecutively without failure
- [x] Full test suite passes on iOS Simulator (fixed tests pass)
- [x] Full test suite passes on macOS (fixed tests pass)
- [x] No new `Task.sleep` calls added without justification
- [x] Execution time delta < 10% (tests complete faster due to condition waiting vs fixed sleeps)
