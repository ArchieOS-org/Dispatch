# Sync Test Coverage Gap Analysis

> **Generated**: 2026-01-19
> **Contract Reference**: sync-test-audit.md
> **Status**: PATCHSET 1

---

## Executive Summary

The sync layer has **good coverage** for individual entity handlers and conflict resolution, but **lacks coverage** for:
1. SyncManager+Operations.swift orchestration (syncDown/syncUp integration)
2. AppCompatManager.swift (no tests at all)
3. Batch operation failure recovery paths
4. Avatar upload failure handling in UserSyncHandler
5. Performance regression detection

---

## 1. Coverage by File

### Production Files Audited

| File | Has Tests | Coverage Level | Gap Priority |
|------|-----------|----------------|--------------|
| `SyncManager.swift` | Partial | Medium | MEDIUM |
| `SyncManager+Operations.swift` | NO | None | **HIGH** |
| `SyncManager+Lifecycle.swift` | Partial | Low | MEDIUM |
| `SyncManager+Realtime.swift` | Partial | Low | LOW |
| `EntitySyncHandler.swift` | Partial | Medium | MEDIUM |
| `ConflictResolver.swift` | YES | High | LOW |
| `CircuitBreaker.swift` | YES | High | LOW |
| `RetryCoordinator.swift` | YES | High | LOW |
| `SyncQueue.swift` | YES | High | LOW |
| `AppCompatManager.swift` | NO | None | **HIGH** |
| `RealtimeManager.swift` | Partial | Low | LOW |
| `Handlers/UserSyncHandler.swift` | YES | High | MEDIUM (avatar gaps) |
| `Handlers/TaskSyncHandler.swift` | YES | High | LOW |
| `Handlers/ActivitySyncHandler.swift` | YES | High | LOW |
| `Handlers/ListingSyncHandler.swift` | YES | High | LOW |
| `Handlers/NoteSyncHandler.swift` | YES | High | LOW |
| `Handlers/PropertySyncHandler.swift` | Partial | Medium | LOW |

### Existing Test Files (17 total)

| Test File | Coverage Focus |
|-----------|----------------|
| `UserSyncHandlerTests.swift` | Upsert, delete, legacy migration |
| `TaskSyncHandlerTests.swift` | Upsert, in-flight protection, assignees |
| `ActivitySyncHandlerTests.swift` | Upsert, in-flight protection, assignees |
| `ListingSyncHandlerTests.swift` | Upsert, in-flight protection |
| `NoteSyncHandlerTests.swift` | Upsert, delete, soft-delete |
| `PropertySyncHandlerTests.swift` | Basic upsert |
| `ConflictResolverTests.swift` | In-flight tracking, isLocalAuthoritative |
| `CircuitBreakerTests.swift` | State machine, cooldown, recovery |
| `RetryCoordinatorTests.swift` | Retry logic, max retries |
| `SyncCoalescingTests.swift` | Request coalescing |
| `SyncQueueTests.swift` | Queue behavior |
| `SyncRelationshipTests.swift` | Listing-User relationship resolution |
| `SyncTests.swift` | DTO mapping basics |
| `SyncManagerIsolationTests.swift` | Mode isolation |
| `BatchSyncResultTests.swift` | Result aggregation |
| `SyncErrorTests.swift` | Error handling |
| `RealtimeRetryTests.swift` | Realtime reconnection |

---

## 2. Gap Analysis by Category

### 2.1 Sync Operation Coverage

| Category | Covered | Gaps |
|----------|---------|------|
| Initial sync (cold start) | NO | `syncDown` first-run path with `shouldReconcile=true` |
| Incremental sync (delta) | Partial | Individual handlers tested, orchestration NOT tested |
| Sync after offline period | NO | `retryFailedEntities` tested, full recovery flow NOT tested |
| Concurrent sync operations | YES | `SyncCoalescingTests` covers coalescing |
| Sync cancellation mid-operation | NO | No test for cancellation during `sync()` |

**Priority**: HIGH - Need integration tests for `SyncManager+Operations.swift`

### 2.2 Error Handling Coverage

| Category | Covered | Gaps |
|----------|---------|------|
| Network failures during sync | Partial | CircuitBreaker tested, but not actual failure propagation |
| Auth token expiration | NO | No test for auth-related sync failures |
| Partial batch failures | NO | **CRITICAL**: Batch-to-individual fallback logic untested |
| Retry exhaustion scenarios | YES | `RetryCoordinatorTests` covers this well |
| Circuit breaker transitions | YES | `CircuitBreakerTests` comprehensive |

**Priority**: HIGH - Batch failure recovery is a critical path

### 2.3 Conflict Resolution Coverage

| Category | Covered | Gaps |
|----------|---------|------|
| In-flight conflict protection | YES | All handlers test this |
| Pending state protection | YES | All handlers test this |
| Failed state protection | YES | All handlers test this |
| Timestamp-based resolution | NO | `lastWriteWins` strategy not directly tested |
| Conflict during offline edit | NO | Complex scenario not covered |

**Priority**: LOW - Core conflict mechanics well tested

### 2.4 Performance Regression Guards

| Category | Covered | Gaps |
|----------|---------|------|
| N+1 query detection | NO | No test to catch inefficient fetch patterns |
| Duplicate iteration detection | NO | No test for O(n^2) loop regressions |
| Batch operations verified | NO | No test confirms batch vs individual execution |
| Coalescing verification | YES | `SyncCoalescingTests` covers this |

**Priority**: HIGH - Performance can regress silently

### 2.5 Data Integrity Coverage

| Category | Covered | Gaps |
|----------|---------|------|
| Relationship maintenance | YES | `SyncRelationshipTests` covers Listing-User |
| Orphan prevention | Partial | `reconcileOrphans` exists but not tested |
| Cascade delete verification | NO | No test for cascade behavior |
| Foreign key integrity | Partial | Relationship tests cover some cases |

**Priority**: MEDIUM - Orphan reconciliation needs tests

### 2.6 Edge Cases

| Category | Covered | Gaps |
|----------|---------|------|
| Empty response handling | Partial | Some handlers test empty arrays |
| Malformed response handling | NO | No test for invalid DTO data |
| Timeout handling | NO | No test for network timeout scenarios |
| Very large batch handling | NO | No test for >100 item sync |
| Rapid consecutive sync triggers | YES | `SyncCoalescingTests` covers this |

**Priority**: MEDIUM - Edge cases can cause production issues

---

## 3. Specific Untested Code Paths

### 3.1 HIGH Priority Gaps

#### Gap 1: SyncManager+Operations syncDown/syncUp Orchestration
**File**: `Dispatch/Foundation/Persistence/Sync/SyncManager+Operations.swift`
**Lines**: 18-117 (syncDown), 119-154 (syncUp)
**Risk**: HIGH
**Issue**: The full sync orchestration calling all handlers in order is not tested
**Anti-Pattern Risk**: Handler order changes could break FK dependencies
**Test Strategy**: Integration test with mock handlers verifying call order and error propagation

#### Gap 2: AppCompatManager Entire File
**File**: `Dispatch/Foundation/Persistence/Sync/AppCompatManager.swift`
**Lines**: 1-186 (entire file)
**Risk**: HIGH
**Issue**: Zero test coverage for version compatibility checking
**Anti-Pattern Risk**: Breaking changes could bypass version checks
**Test Strategy**: Unit tests for `checkCompatibility()`, `preSyncCheck()`, and status computation

#### Gap 3: Batch Upsert Failure Recovery
**File**: `Dispatch/Foundation/Persistence/Sync/Handlers/TaskSyncHandler.swift`
**Lines**: 80-116 (syncUp batch logic)
**Risk**: HIGH
**Issue**: Batch failure falls back to individual upserts - this path is untested
**Anti-Pattern Risk**: Fallback could fail silently or mark wrong items as synced
**Test Strategy**: Mock Supabase to fail batch, verify individual fallback works correctly

#### Gap 4: UserSyncHandler Avatar Upload Failure
**File**: `Dispatch/Foundation/Persistence/Sync/Handlers/UserSyncHandler.swift`
**Lines**: 273-326 (uploadAvatarAndSyncUser)
**Risk**: HIGH
**Issue**: `uploadFailed = true` skip logic (line 315-318) is not tested
**Anti-Pattern Risk**: Users could silently lose avatar updates
**Test Strategy**: Mock storage upload failure, verify user stays pending and avatar preserved

### 3.2 MEDIUM Priority Gaps

#### Gap 5: Orphan Reconciliation
**File**: `Dispatch/Foundation/Persistence/Sync/EntitySyncHandler.swift`
**Lines**: 440-480 (reconcileOrphans)
**Risk**: MEDIUM
**Issue**: Orphan detection and deletion not directly tested
**Test Strategy**: Create local entities not on server, verify deletion

#### Gap 6: Stale Timestamp Detection
**File**: `Dispatch/Foundation/Persistence/Sync/SyncManager.swift`
**Lines**: 278-304 (detectAndResetStaleTimestamp)
**Risk**: MEDIUM
**Issue**: Logic to detect empty DB with stale timestamp not tested
**Test Strategy**: Set lastSyncTime with empty context, verify reset

#### Gap 7: Missing Entity Reconciliation
**File**: `Dispatch/Foundation/Persistence/Sync/Handlers/TaskSyncHandler.swift`
**Lines**: 176-217 (reconcileMissingTasks)
**Risk**: MEDIUM
**Issue**: Reconciliation that fetches missing entities not tested
**Test Strategy**: Create server entities not locally, verify fetch

### 3.3 LOW Priority Gaps

#### Gap 8: Admin-Only Sync Paths
**File**: `Dispatch/Foundation/Persistence/Sync/SyncManager+Operations.swift`
**Lines**: 129-137 (admin ListingTypes/ActivityTemplates sync)
**Risk**: LOW
**Issue**: Admin vs non-admin sync path branching not tested
**Test Strategy**: Test with admin vs non-admin user type

#### Gap 9: Realtime Event Handling
**File**: `Dispatch/Foundation/Persistence/Sync/RealtimeManager.swift`
**Risk**: LOW
**Issue**: Event parsing and handling partially tested
**Test Strategy**: Mock realtime events, verify correct handler dispatch

---

## 4. Anti-Pattern Risk Assessment

### 4.1 O(n^2) Loop Patterns
**Current Code**: `reconcileListingRelationships` uses batch fetch + O(1) dictionary lookup
**Risk**: Someone could refactor to per-listing fetch (O(n) queries)
**Detection Strategy**: Performance test with 100+ items, measure duration

### 4.2 Watermark Race Condition
**Current Code**: `lastSyncTime` is set AFTER `context.save()` (line 597-598 in SyncManager.swift)
**Risk**: If watermark set before save, data could be lost on crash
**Detection Strategy**: Integration test verifying order of operations

### 4.3 Retry Count Reset on Recreation
**Current Code**: `markSynced()` resets `retryCount` to 0
**Risk**: Entity recreation could reset retry count, causing infinite retry loops
**Detection Strategy**: Test that retry count persists across sync cycles until success

### 4.4 Duplicate Item Marking
**Current Code**: Batch success marks all items synced (lines 92-94 in TaskSyncHandler)
**Risk**: If batch partially succeeds, wrong items could be marked synced
**Detection Strategy**: Mock partial batch failure, verify only successful items marked

---

## 5. Proposed Test Implementation Plan

### Phase 1: High Priority (PATCHSET 2)

1. **SyncManagerOperationsTests.swift** (NEW)
   - `test_syncDown_callsHandlersInCorrectOrder`
   - `test_syncDown_propagatesHandlerErrors`
   - `test_syncUp_callsHandlersInFKDependencyOrder`
   - `test_sync_runsDownThenUp`
   - `test_sync_firstSyncTriggersReconciliation`

2. **AppCompatManagerTests.swift** (NEW)
   - `test_checkCompatibility_returnsCompatibleWhenVersionMatches`
   - `test_checkCompatibility_returnsUpdateRequiredWhenBelowMinVersion`
   - `test_checkCompatibility_returnsUnknownOnNetworkError`
   - `test_preSyncCheck_usesCachedResultWithinCooldown`
   - `test_canProceed_returnsFalseWhenUpdateRequired`

3. **BatchOperationRecoveryTests.swift** (NEW)
   - `test_syncUpTasks_fallsBackToIndividualOnBatchFailure`
   - `test_syncUpTasks_marksOnlySuccessfulItemsSynced`
   - `test_syncUpTasks_marksFailedItemsWithError`
   - `test_syncUpTasks_doesNotResetRetryCountOnFallback`

4. **UserSyncHandlerAvatarTests.swift** (ADD to existing)
   - `test_uploadAvatarAndSyncUser_skipsUpsertOnUploadFailure`
   - `test_uploadAvatarAndSyncUser_preservesAvatarOnUploadFailure`
   - `test_uploadAvatarAndSyncUser_userStaysPendingOnUploadFailure`

### Phase 2: Medium Priority (Future)

5. **SyncPerformanceTests.swift** (NEW)
   - `test_syncDown_100Items_completesWithinThreshold`
   - `test_reconcileListingRelationships_usesEfficientBatchLookup`
   - `test_batchUpsert_preferredOverIndividual`

6. **OrphanReconciliationTests.swift** (NEW)
   - `test_reconcileOrphans_deletesLocalOnlyEntities`
   - `test_reconcileOrphans_preservesServerEntities`

---

## 6. Test Infrastructure Notes

### Existing Test Patterns
- In-memory `ModelContainer` for SwiftData isolation
- `SyncRunMode.test` disables network and timers
- `SyncHandlerDependencies` provides injectable mocks
- `ConflictResolver` is injectable for in-flight tracking tests

### Needed Infrastructure
- **Mock Supabase Client**: For testing network failure scenarios
- **Mock Storage**: For testing avatar upload failures
- **Performance Baseline**: XCTest measure blocks for regression detection

---

## 7. Acceptance Criteria Mapping

| Acceptance Criteria | How Tests Will Address |
|---------------------|------------------------|
| Gap Analysis Complete | This document |
| Anti-Pattern Detection Tests | SyncPerformanceTests, BatchOperationRecoveryTests |
| Correctness Regression Tests | SyncManagerOperationsTests, AppCompatManagerTests, Avatar tests |

---

**END OF GAP ANALYSIS**
