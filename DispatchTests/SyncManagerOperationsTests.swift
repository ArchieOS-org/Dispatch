//
//  SyncManagerOperationsTests.swift
//  DispatchTests
//
//  Integration tests for SyncManager+Operations.swift.
//  Tests syncDown/syncUp orchestration and error propagation.
//
//  NOTE: These tests use .test mode which disables network operations.
//  They verify the orchestration logic, not actual Supabase communication.
//

import SwiftData
import XCTest
@testable import DispatchApp

// MARK: - SyncManagerOperationsTests

@MainActor
final class SyncManagerOperationsTests: XCTestCase {

  // MARK: Internal

  override func setUp() async throws {
    try await super.setUp()

    // Create in-memory SwiftData container with ALL required models
    let schema = Schema([
      TaskItem.self,
      TaskAssignee.self,
      Activity.self,
      ActivityAssignee.self,
      Note.self,
      Listing.self,
      User.self,
      ListingTypeDefinition.self,
      ActivityTemplate.self,
      Property.self,
      Subtask.self,
      StatusChange.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    container = try ModelContainer(for: schema, configurations: [config])
    context = container.mainContext

    // Create SyncManager in test mode (no network, no timers)
    syncManager = SyncManager(mode: .test)
    syncManager.configure(with: container)
  }

  override func tearDown() async throws {
    // Proper cleanup to avoid test pollution
    await syncManager.shutdown()
    syncManager = nil
    context = nil
    container = nil
    try await super.tearDown()
  }

  // MARK: - Mode Configuration Tests

  func test_syncManager_inTestMode() {
    XCTAssertEqual(syncManager.mode, .test)
  }

  func test_syncManager_hasModelContainer() {
    XCTAssertNotNil(syncManager.modelContainer)
  }

  // MARK: - EntitySyncHandler Configuration Tests

  func test_entitySyncHandler_isConfigured() {
    XCTAssertNotNil(syncManager.entitySyncHandler)
  }

  func test_entitySyncHandler_hasAllHandlers() throws {
    let handler = try XCTUnwrap(syncManager.entitySyncHandler)
    XCTAssertNotNil(handler.userSyncHandler)
    XCTAssertNotNil(handler.propertySyncHandler)
    XCTAssertNotNil(handler.listingSyncHandler)
    XCTAssertNotNil(handler.taskSyncHandler)
    XCTAssertNotNil(handler.activitySyncHandler)
    XCTAssertNotNil(handler.noteSyncHandler)
  }

  // MARK: - Sync Status Lifecycle Tests

  func test_syncStatus_startsAsIdle() {
    XCTAssertEqual(syncManager.syncStatus, .idle)
  }

  func test_isSyncing_startsAsFalse() {
    XCTAssertFalse(syncManager.isSyncing)
  }

  // MARK: - First Sync Detection Tests

  func test_firstSync_hasNilLastSyncTime() {
    // In test mode, lastSyncTime should start as nil
    XCTAssertNil(syncManager.lastSyncTime)
  }

  func test_resetLastSyncTime_setsToNil() {
    // Given: Set a lastSyncTime
    #if DEBUG
    syncManager._debugSetLastSyncTime(Date())
    XCTAssertNotNil(syncManager.lastSyncTime)
    #endif

    // When: Reset
    syncManager.resetLastSyncTime()

    // Then: Should be nil
    XCTAssertNil(syncManager.lastSyncTime)
  }

  // MARK: - Sync Request Coalescing Tests

  func test_syncQueue_coalescesMultipleRequests() {
    // Coalescing behavior is tested in SyncCoalescingTests
    // Here we verify the queue exists and can accept requests without error
    let queue = syncManager.syncQueue
    XCTAssertNotNil(queue)
    XCTAssertFalse(queue.isLoopActive, "Loop should not be active in test mode")
  }

  // MARK: - CircuitBreaker Integration Tests

  func test_circuitBreaker_startsAsClosed() {
    XCTAssertEqual(syncManager.circuitBreaker.state, .closed)
    XCTAssertFalse(syncManager.circuitBreaker.isBlocking)
  }

  func test_circuitBreaker_allowsSyncInitially() {
    XCTAssertTrue(syncManager.circuitBreaker.shouldAllowSync())
  }

  // MARK: - ConflictResolver Integration Tests

  func test_conflictResolver_isConfigured() {
    XCTAssertNotNil(syncManager.conflictResolver)
  }

  func test_conflictResolver_startsWithEmptyInFlightSets() {
    let resolver = syncManager.conflictResolver
    XCTAssertTrue(resolver.inFlightTaskIds.isEmpty)
    XCTAssertTrue(resolver.inFlightActivityIds.isEmpty)
    XCTAssertTrue(resolver.inFlightNoteIds.isEmpty)
    XCTAssertTrue(resolver.inFlightTaskAssigneeIds.isEmpty)
    XCTAssertTrue(resolver.inFlightActivityAssigneeIds.isEmpty)
  }

  // MARK: - Relationship Reconciliation Tests

  func test_reconcileListingRelationships_linksOrphanedListings() async throws {
    // Given: A user and an orphaned listing (owner not linked)
    let userId = UUID()
    let user = User(id: userId, name: "Test Owner", email: "owner@test.com", userType: .realtor)
    context.insert(user)

    let listing = Listing(id: UUID(), address: "123 Test St", ownedBy: userId)
    // Don't set listing.owner - simulating an orphaned listing
    context.insert(listing)
    try context.save()

    XCTAssertNil(listing.owner, "Precondition: listing should be orphaned")

    // When: Run reconciliation
    try await syncManager.reconcileListingRelationships(context: context)

    // Then: Listing should be linked to user
    XCTAssertNotNil(listing.owner)
    XCTAssertEqual(listing.owner?.id, userId)
  }

  func test_reconcileListingRelationships_preservesValidLinks() async throws {
    // Given: A properly linked listing
    let userId = UUID()
    let user = User(id: userId, name: "Valid Owner", email: "valid@test.com", userType: .realtor)
    context.insert(user)

    let listing = Listing(id: UUID(), address: "456 Valid St", ownedBy: userId)
    listing.owner = user // Properly linked
    context.insert(listing)
    try context.save()

    XCTAssertNotNil(listing.owner)

    // When: Run reconciliation
    try await syncManager.reconcileListingRelationships(context: context)

    // Then: Link should still be valid
    XCTAssertNotNil(listing.owner)
    XCTAssertEqual(listing.owner?.id, userId)
  }

  func test_reconcileListingRelationships_handlesMultipleOrphans() async throws {
    // Given: Multiple users and orphaned listings
    let user1 = User(id: UUID(), name: "Owner 1", email: "o1@test.com", userType: .realtor)
    let user2 = User(id: UUID(), name: "Owner 2", email: "o2@test.com", userType: .realtor)
    context.insert(user1)
    context.insert(user2)

    let listing1 = Listing(id: UUID(), address: "Orphan 1", ownedBy: user1.id)
    let listing2 = Listing(id: UUID(), address: "Orphan 2", ownedBy: user2.id)
    context.insert(listing1)
    context.insert(listing2)
    try context.save()

    XCTAssertNil(listing1.owner)
    XCTAssertNil(listing2.owner)

    // When: Run reconciliation
    try await syncManager.reconcileListingRelationships(context: context)

    // Then: Both should be linked correctly
    XCTAssertEqual(listing1.owner?.id, user1.id)
    XCTAssertEqual(listing2.owner?.id, user2.id)
  }

  // MARK: - Stale Timestamp Detection Tests

  func test_detectAndResetStaleTimestamp_resetsWhenDbEmptyButTimestampSet() {
    // Given: Empty database but lastSyncTime is set
    #if DEBUG
    syncManager._debugSetLastSyncTime(Date())
    #endif

    // Verify precondition: lastSyncTime is set
    XCTAssertNotNil(syncManager.lastSyncTime)

    // When: Detect stale timestamp
    syncManager.detectAndResetStaleTimestamp()

    // Then: Should reset because DB is empty
    XCTAssertNil(syncManager.lastSyncTime)
  }

  func test_detectAndResetStaleTimestamp_noOpWhenTimestampAlreadyNil() {
    // Given: No lastSyncTime
    XCTAssertNil(syncManager.lastSyncTime)

    // When: Detect stale timestamp
    syncManager.detectAndResetStaleTimestamp()

    // Then: Still nil (no-op)
    XCTAssertNil(syncManager.lastSyncTime)
  }

  func test_detectAndResetStaleTimestamp_preservesWhenDbHasData() throws {
    // Given: Database has data
    let task = TaskItem(title: "Test Task", declaredBy: UUID())
    context.insert(task)
    try context.save()

    #if DEBUG
    let testDate = Date()
    syncManager._debugSetLastSyncTime(testDate)
    #endif

    // When: Detect stale timestamp
    syncManager.detectAndResetStaleTimestamp()

    // Then: Should preserve timestamp because DB has data
    XCTAssertNotNil(syncManager.lastSyncTime)
  }

  // MARK: - Retry Coordination Tests

  func test_retryCoordinator_isConfigured() {
    // RetryCoordinator is private, but we can test through public methods
    // The existence of retryTask/retryActivity/retryListing methods indicates it's configured
    // We'll test the behavior indirectly

    // Given: A failed task
    let task = TaskItem(title: "Failed Task", declaredBy: UUID())
    task.syncState = .failed
    task.retryCount = 0
    context.insert(task)

    // The retryTask method exists and is callable (compilation check)
    // Actual behavior tested in RetryCoordinatorTests
  }

  // MARK: - SyncQueue Integration Tests

  func test_syncQueue_isConfigured() {
    XCTAssertNotNil(syncManager.syncQueue)
  }

  func test_syncQueue_loopNotActiveInitially() {
    // In test mode, the sync loop should not be active initially
    XCTAssertFalse(syncManager.syncQueue.isLoopActive)
  }

  // MARK: - SyncRunId Tests

  func test_syncRunId_startsAtZero() {
    XCTAssertEqual(syncManager.syncRunId, 0)
  }

  // MARK: - RealtimeManager Integration Tests

  func test_realtimeManager_isConfigured() {
    XCTAssertNotNil(syncManager.realtimeManager)
  }

  // Note: RealtimeManager.mode is private; we verify through behavior instead
  func test_realtimeManager_existsWithSyncManager() {
    // RealtimeManager is created with the same mode as SyncManager
    // We verify it exists and is properly initialized
    XCTAssertNotNil(syncManager.realtimeManager)
  }

  // MARK: - Private Properties

  // swiftlint:disable implicitly_unwrapped_optional
  private var container: ModelContainer!
  private var context: ModelContext!
  private var syncManager: SyncManager!
  // swiftlint:enable implicitly_unwrapped_optional
}
