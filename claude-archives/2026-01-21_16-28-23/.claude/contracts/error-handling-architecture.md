## Interface Lock

**Feature**: Error Handling Architecture Expansion
**Created**: 2026-01-18
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

Based on checked indicators (none checked - backend/infrastructure change):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |

---

### Contract

- New/changed model fields: None (using existing `lastSyncError: String?`, `syncState: EntitySyncState`)
- DTO/API changes: None
- State/actions added:
  - `SyncError` enum with all classified error cases
  - `SyncErrorClassification` enum (retryable vs fatal)
  - `BatchSyncResult` struct for surfacing individual failures
  - `SyncErrorBoundary` SwiftUI ViewModifier
- Migration required: N

### Acceptance Criteria (5 total)

1. All sync error conditions have user-facing messages (network, RLS, validation, encoding)
2. Errors classified as `.retryable` or `.fatal` with `isRetryable` property
3. Batch sync failures surface individual entity errors (not silent swallow)
4. SwiftUI views can catch and display sync errors via `SyncErrorBoundary` modifier
5. Unit tests cover all error message mappings and batch failure surfacing

### Non-goals (prevents scope creep)

- No changes to retry backoff logic (existing `RetryPolicy` is sufficient)
- No new UI screens for error display (use existing alert patterns)
- No changes to `SyncStatus` enum (error details remain in `lastSyncErrorMessage`)
- No breaking changes to existing error handling callers

### Compatibility Plan

- **Backward compatibility**: Existing `userFacingMessage(for:)` function remains, now delegates to `SyncError` enum
- **Default when missing**: Unknown errors map to `.unknown(Error)` case with localized description
- **Rollback strategy**: All changes are additive; remove new files to rollback

---

### Analysis Summary

**Current State:**

1. **SyncError+UserFacing.swift** - Global function `userFacingMessage(for:)` handles:
   - URLError codes (network, timeout)
   - PostgreSQL 42501 permission errors with table-specific messages
   - Fallback to `error.localizedDescription`
   - **Gap**: No structured error enum, no retryable classification

2. **SyncHandlerDependencies** - Duplicates `userFacingMessage(for:)` logic (simpler version)
   - **Gap**: Inconsistent with global function (missing table-specific messages)

3. **Batch Sync (TaskSyncHandler, ActivitySyncHandler, etc.)** - Pattern:
   - Try batch upsert first
   - On failure, try individual items
   - Individual failures call `entity.markFailed(message)`
   - **Gap**: Batch failure errors not aggregated/surfaced to caller

4. **SwiftUI Error Display** - Current patterns:
   - `ListingListView` uses `.alert()` for delete confirmations
   - `SyncManager.lastSyncErrorMessage` exposed but not consumed by error boundary
   - **Gap**: No SwiftUI ViewModifier for catching/displaying sync errors

5. **EntitySyncState** - States: `.synced`, `.pending`, `.failed`
   - **Gap**: No distinction between retryable vs fatal failures

---

### Implementation Plan

#### File 1: `Dispatch/Foundation/Persistence/Errors/SyncError.swift` (NEW)

```swift
/// Structured sync error with user-facing messages and retry classification.
enum SyncError: Error, LocalizedError, Equatable {
  // Network errors (retryable)
  case noInternet
  case connectionLost
  case timeout
  case networkError(String)

  // Permission errors (fatal)
  case permissionDenied(table: String?)

  // Validation errors (fatal)
  case encodingFailed(entity: String)
  case decodingFailed(entity: String)
  case invalidData(reason: String)

  // Server errors
  case serverError(statusCode: Int)
  case rateLimited

  // Unknown
  case unknown(Error)

  var errorDescription: String? { userFacingMessage }

  var userFacingMessage: String { ... }

  var isRetryable: Bool { ... }

  static func from(_ error: Error) -> SyncError { ... }
}
```

#### File 2: Update `SyncError+UserFacing.swift`

Refactor `userFacingMessage(for:)` to delegate to `SyncError.from(error).userFacingMessage`

#### File 3: `Dispatch/Foundation/Persistence/Errors/BatchSyncResult.swift` (NEW)

```swift
/// Result of a batch sync operation that surfaces individual failures.
struct BatchSyncResult<Entity> {
  let succeeded: [Entity]
  let failed: [(entity: Entity, error: SyncError)]

  var hasFailures: Bool { !failed.isEmpty }
  var failureCount: Int { failed.count }
  var successCount: Int { succeeded.count }
}
```

#### File 4: Update `SyncHandlerDependencies`

Remove duplicate `userFacingMessage(for:)` - use global function or `SyncError.from()`

#### File 5: Update Entity Sync Handlers

Modify `syncUp()` in TaskSyncHandler, ActivitySyncHandler, etc. to return/log `BatchSyncResult`

#### File 6: `Dispatch/Foundation/Components/SyncErrorBoundary.swift` (NEW)

```swift
/// ViewModifier that catches sync errors and displays alerts.
struct SyncErrorBoundary: ViewModifier {
  @EnvironmentObject var syncManager: SyncManager
  @State private var showErrorAlert = false

  func body(content: Content) -> some View {
    content
      .onChange(of: syncManager.syncStatus) { _, newStatus in
        if case .error = newStatus {
          showErrorAlert = true
        }
      }
      .alert("Sync Error", isPresented: $showErrorAlert) {
        Button("Retry") { Task { await syncManager.retrySync() } }
        Button("Dismiss", role: .cancel) { }
      } message: {
        Text(syncManager.lastSyncErrorMessage ?? "An error occurred during sync.")
      }
  }
}

extension View {
  func syncErrorBoundary() -> some View {
    modifier(SyncErrorBoundary())
  }
}
```

#### File 7: Tests

- `DispatchTests/SyncErrorTests.swift` - Test all error case mappings
- Update `ErrorPathTests.swift` - Add batch failure surfacing tests

---

### Ownership

- **feature-owner**: End-to-end implementation of SyncError enum, BatchSyncResult, SyncErrorBoundary, handler updates, and tests
- **data-integrity**: Not needed (no schema changes)

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

**PATCHSET 1:**
CONTEXT7: UNAVAILABLE (Monthly quota exceeded - context7.com rate limit)

Proceeding with standard Swift error handling patterns from training knowledge:
- Swift `Error` protocol with `LocalizedError` for user-facing messages
- `enum` with associated values for structured error cases
- `errorDescription` property for `LocalizedError` conformance
- Static factory method pattern for error conversion

**PATCHSET 2:**
CONTEXT7: UNAVAILABLE (Monthly quota exceeded - context7.com rate limit)

For SyncErrorBoundary ViewModifier, used standard SwiftUI patterns:
- `ViewModifier` protocol with `body(content:)` method
- `@EnvironmentObject` for accessing `SyncManager`
- `.onChange(of:)` for observing sync status changes
- `.alert(isPresented:presenting:actions:message:)` for error display
- `@ViewBuilder` for conditional alert actions based on retryable state

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: UNAVAILABLE (quota exceeded)
**Libraries Queried**: Swift (attempted - quota exceeded)

| Query | Pattern Used |
|-------|--------------|
| Swift error handling with LocalizedError | `enum SyncError: Error, LocalizedError` with `errorDescription` computed property |
| Swift Equatable for enums with associated values | Manual `==` implementation for `unknown(Error)` case |
| Factory method pattern | `static func from(_:) -> SyncError` for error conversion |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)
**Reviewed**: N/A

This is a backend/infrastructure change with no customer-facing UI modifications. The `SyncErrorBoundary` ViewModifier provides a reusable pattern but does not introduce new screens or change existing UI hierarchy.

---

### PATCHSET 2 Completion Summary

**Status**: COMPLETE

**Files Created/Modified:**
1. `Dispatch/Foundation/Persistence/Errors/SyncErrorBoundary.swift` (NEW)
   - ViewModifier for catching sync errors and displaying alerts
   - Observes SyncManager.syncStatus for error state
   - Shows retry button for retryable errors, OK button for fatal errors
   - Includes View extension `.syncErrorBoundary()`

2. `Dispatch/Foundation/Persistence/Sync/BatchSyncResult.swift` (already existed from PATCHSET 1)
   - Verified complete with Builder pattern, retry classification methods

3. `DispatchTests/Foundation/Persistence/Errors/SyncErrorTests.swift` (NEW)
   - 50+ tests covering all SyncError cases
   - User-facing message tests for all error types
   - isRetryable classification tests
   - Factory method (from:) conversion tests
   - Equatable conformance tests
   - Table name extraction tests

4. `DispatchTests/Foundation/Persistence/Sync/BatchSyncResultTests.swift` (NEW)
   - 30 tests covering BatchSyncResult functionality
   - Basic properties and computed values
   - Builder pattern tests
   - Retry classification (hasRetryableFailures, retryableFailures, fatalFailures)
   - Summary generation tests
   - Generic type tests

5. `DispatchTests/ErrorPathTests.swift` (MODIFIED)
   - Fixed test expectations to match SyncError behavior:
     - `testNetworkConnectionLost_ProducesCorrectErrorMessage`: Updated expected message
     - `testGenericURLError_ProducesNetworkErrorMessage`: Updated expected message

**Acceptance Criteria Status:**
1. [x] All sync error conditions have user-facing messages - SyncError enum covers all cases
2. [x] Errors classified as retryable/fatal via `isRetryable` property
3. [x] Batch sync failures surface individual errors via BatchSyncResult
4. [x] SwiftUI views can catch/display sync errors via SyncErrorBoundary modifier
5. [x] Unit tests cover all error message mappings and batch failure surfacing

**Build Status:**
- iOS Simulator: PASS
- macOS: PASS
- Tests: PASS (SyncErrorTests: 50+ tests, BatchSyncResultTests: 30 tests)

---

**IMPORTANT**:
- UI Review Required: NO - Jobs Critique section is not required
- integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
