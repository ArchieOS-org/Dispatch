## Interface Lock

**Feature**: Error Path Tests
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
- [x] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators (test-only, no UI, no schema):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles, mocks created | feature-owner |
| 2 | All error path tests pass | feature-owner, integrator |

**Note**: Simplified 2-patchset plan since this is test-only work with no UI or schema changes.

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None (test infrastructure only)
- Migration required: N

### Acceptance Criteria (3 max)

1. ErrorPathTests.swift created with mocks for network layer, Supabase client, and SwiftData context
2. All 5 error scenarios tested: network timeout, 403 response, 500 response, retry exhaustion, SwiftData save failure
3. All new error tests pass on both iOS Simulator and macOS

### Non-goals (prevents scope creep)

- No changes to production SyncManager code
- No real network calls (all mocked)
- No UI tests (unit tests only)
- No refactoring SyncManager for testability (use existing test modes where possible)

### Compatibility Plan

- **Backward compatibility**: N/A (test-only)
- **Default when missing**: N/A
- **Rollback strategy**: Delete test file if needed

---

### Ownership

- **feature-owner**: Create ErrorPathTests.swift with mock infrastructure and all error scenario tests
- **data-integrity**: Not needed
- **dispatch-explorer**: Required first to understand:
  - Sync architecture (SyncManager, EntitySyncHandler, Supabase client)
  - Existing test patterns (SyncTests, SyncCoalescingTests, RetryPolicyTests)
  - Error handling in SyncManager.userFacingMessage(for:)
  - Retry logic (RetryPolicy, retryTask, retryActivity, retryListing)
  - Mode switching (.live, .preview, .test) for test isolation

---

### Exploration Findings (to be filled by dispatch-explorer)

#### Sync Architecture Summary

- `SyncManager` (@MainActor, singleton) orchestrates bidirectional sync
- `EntitySyncHandler` handles per-entity sync operations
- `SyncRunMode`: .live, .preview, .test (test mode disables network/timers)
- Supabase client accessed via global `supabase` instance
- Error handling: `syncError` published property, `userFacingMessage(for:)` for user-facing strings

#### Error Handling Points

1. **Network errors**: URLError cases (notConnectedToInternet, timedOut, etc.)
2. **Supabase errors**: PostgrestError (403/permission denied, 500/server errors)
3. **SwiftData errors**: context.save() failures
4. **Retry exhaustion**: retryCount >= RetryPolicy.maxRetries (5)

#### Existing Test Patterns

- `SyncManager(mode: .test)` for isolated testing
- `_simulateCoalescingInTest` flag for testing sync loop
- No existing mocking infrastructure for Supabase client
- Tests use XCTest, @MainActor, async/await

#### Mocking Strategy Recommendation

Option A: Protocol-based mocking (requires production changes - out of scope)
Option B: Use `.test` mode + manual error injection via test hooks
Option C: Create mock DTOs that simulate error responses

**Recommended**: Option B/C hybrid - leverage existing `.test` mode and add minimal test hooks if needed. If hooks require production changes, simulate errors at the highest possible level.

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

- [Swift]: XCTest async error testing patterns
- [Swift]: SwiftData ModelContext error handling in tests

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: N/A
**Libraries Queried**: N/A (test-only, uses existing XCTest/SwiftData patterns already in codebase)

| Query | Pattern Used |
|-------|--------------|
| N/A | Followed existing test patterns from SyncRelationshipTests.swift, SyncManagerIsolationTests.swift |

**Rationale**: This is a test-only implementation that:
- Uses standard XCTest patterns already established in the codebase
- Uses in-memory ModelContainer pattern from SyncRelationshipTests.swift
- Uses SyncManager(mode: .test) pattern from SyncManagerIsolationTests.swift
- Tests existing production code (userFacingMessage, retryTask, etc.) without modifying it
- No new framework patterns introduced

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (No UI changes)
**Reviewed**: N/A

#### Checklist

N/A - Test-only changes, no customer-facing UI.

#### Verdict Notes

Jobs Critique not required for this contract as UI Review Required: NO.

---

### Test Scenarios to Implement

1. **Network Timeout**
   - Simulate URLError.timedOut
   - Verify syncStatus becomes .error
   - Verify lastSyncErrorMessage is user-friendly

2. **403 Forbidden (RLS/Permission Denied)**
   - Simulate PostgrestError with code 42501
   - Verify appropriate error message per table (notes, listings, tasks, etc.)
   - Verify app does not crash

3. **500 Server Error**
   - Simulate server error response
   - Verify graceful degradation
   - Verify error state is recoverable

4. **Retry Exhaustion**
   - Create entity with retryCount at max
   - Attempt retry
   - Verify retry returns false
   - Verify entity remains in .failed state

5. **SwiftData Save Failure**
   - Simulate context.save() throwing
   - Verify error is caught and reported
   - Verify no data corruption

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
