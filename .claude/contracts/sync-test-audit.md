## Interface Lock

**Feature**: Sync and Data Test Coverage Audit
**Created**: 2026-01-19
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [x] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [x] **Unfamiliar area** (adds dispatch-explorer)

---

### Patchset Plan

Based on checked indicators (high-risk + unfamiliar area):

| Patchset | Gate | Agents | Status |
|----------|------|--------|--------|
| 0.5 | Exploration complete | dispatch-explorer | DONE |
| 1 | Gap analysis document ready | feature-owner | DONE |
| 2 | Tests implemented, all pass | feature-owner, integrator | DONE |
| 3 | Validation (tests catch anti-patterns) | xcode-pilot | PENDING |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Scope: Files Under Audit

**Production Code (Sync Layer)**:
- `Dispatch/Foundation/Persistence/Sync/` (all files)
- `Dispatch/Foundation/Persistence/Enums/` (sync-related)
- `Dispatch/Foundation/Persistence/Errors/` (sync errors)
- `Dispatch/Foundation/Persistence/Protocols/RealtimeSyncable.swift`
- `Dispatch/App/State/SyncCoordinator.swift`

**Existing Test Files**:
- `DispatchTests/*Sync*.swift` (14 files)
- `DispatchTests/Foundation/Persistence/` (3 files)
- `DispatchTests/Persistence/Sync/` (1 file)
- `DispatchTests/ConflictResolverTests.swift`
- `DispatchTests/RetryCoordinatorTests.swift`
- `DispatchTests/RetryPolicyTests.swift`
- `DispatchTests/ChannelLifecycleConcurrencyTests.swift`

### Acceptance Criteria (3 max)

1. **Gap Analysis Complete**: Document listing all sync/data files with coverage status, identifying specific untested code paths and edge cases
2. **Anti-Pattern Detection Tests**: Tests that would fail if N+1 queries, duplicate loops, or inefficient patterns were introduced (performance regression guards)
3. **Correctness Regression Tests**: Tests covering sync edge cases (conflicts, offline mode, retry exhaustion, partial failures) that would fail if logic regressed

### Non-goals (prevents scope creep)

- No refactoring of production sync code (audit only)
- No new sync features or capabilities
- No changes to sync handler implementations
- No performance benchmarks (this is coverage, not perf testing)
- No UI tests for sync status indicators

### Compatibility Plan

- **Backward compatibility**: N/A (tests only)
- **Default when missing**: N/A
- **Rollback strategy**: Revert test additions if they cause CI instability

---

### Ownership

- **feature-owner**: Full test coverage implementation for sync/data layer
- **dispatch-explorer**: Map sync layer architecture, identify all code paths needing coverage
- **xcode-pilot**: Validate tests catch the anti-patterns by introducing them and verifying test failure
- **data-integrity**: Not needed (no schema changes)

---

### Gap Analysis Categories

The audit must identify gaps in these specific categories:

#### 1. Sync Operation Coverage
- [ ] Initial sync (cold start)
- [ ] Incremental sync (delta updates)
- [ ] Sync after offline period
- [ ] Concurrent sync operations
- [ ] Sync cancellation mid-operation

#### 2. Error Handling Coverage
- [ ] Network failures during sync
- [ ] Auth token expiration during sync
- [ ] Partial batch failures
- [ ] Retry exhaustion scenarios
- [ ] Circuit breaker state transitions

#### 3. Conflict Resolution Coverage
- [ ] Server-wins conflicts
- [ ] Client-wins conflicts
- [ ] Merge conflicts (if applicable)
- [ ] Timestamp-based resolution
- [ ] Conflict during offline edit

#### 4. Performance Regression Guards
- [ ] Tests that fail on N+1 query patterns
- [ ] Tests that fail on duplicate iteration
- [ ] Tests that verify batch operations are batched
- [ ] Tests that verify coalescing works correctly

#### 5. Data Integrity Coverage
- [ ] Entity relationships maintained after sync
- [ ] Orphan prevention (parent deleted, child exists)
- [ ] Cascade delete verification
- [ ] Foreign key integrity

#### 6. Edge Cases
- [ ] Empty response handling
- [ ] Malformed response handling
- [ ] Timeout handling
- [ ] Very large batch handling
- [ ] Rapid consecutive sync triggers

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: XCTest async await testing patterns MainActor performance measure
CONTEXT7_TAKEAWAYS:
- Use `func testMethod() async throws` for async tests, await async operations directly
- Use `measure {}` block for performance testing with automatic 10 iterations
- Use `measureMetrics([.wallClockTime], automaticallyStartMeasuring: false)` for fine-grained control
- Use `XCTestExpectation` with `expectedFulfillmentCount` for multiple async completions
- Prefer Swift concurrency (`await`) over XCTestExpectation where possible
CONTEXT7_APPLIED:
- async/await pattern -> All new test files (SyncManagerOperationsTests, AppCompatManagerTests, etc.)
- measure {} blocks -> SyncPerformanceTests.swift (planned for Phase 2)

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: Swift XCTest (/swiftlang/swift-corelibs-xctest), Swift Testing (/websites/developer_apple_testing)

| Query | Pattern Used |
|-------|--------------|
| XCTest async await testing patterns | Direct `async throws` test functions with `await` |
| Performance measurement | `measure {}` blocks for baseline timing |
| Multiple async completions | `XCTestExpectation` with `expectedFulfillmentCount` |

**N/A**: Only valid for pure refactors with no framework/library usage.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)
**Reviewed**: N/A

#### Checklist

N/A - No UI changes

#### Verdict Notes

This is a test coverage audit with no customer-facing UI changes. Jobs Critique is not applicable.

---

### Implementation Notes

**Context7 Usage Required For**:
- XCTest async/await patterns (Swift concurrency in tests)
- XCTest performance measurement APIs
- Mocking patterns for Supabase client

**Anti-Pattern Detection Strategy**:
To verify tests catch anti-patterns, xcode-pilot should:
1. Temporarily introduce an N+1 pattern in a sync handler
2. Run the test suite
3. Verify at least one test fails
4. Revert the change
5. Document which test caught it

**Test Organization**:
New tests should follow existing patterns in `DispatchTests/` and maintain parallel structure to production code.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
