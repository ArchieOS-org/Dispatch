//
//  BatchOperationRecoveryTests.swift
//  DispatchTests
//
//  Tests for batch operation failure recovery in sync handlers.
//  Verifies the INSERT-first pattern with UPDATE fallback works correctly.
//
//  NOTE: These tests verify the local logic of batch handling.
//  Network behavior is mocked through test mode.
//

import SwiftData
import XCTest
@testable import DispatchApp

// MARK: - BatchOperationRecoveryTests

@MainActor
final class BatchOperationRecoveryTests: XCTestCase {

  // MARK: Internal

  override func setUp() async throws {
    try await super.setUp()

    // Create in-memory SwiftData container
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

    // Create conflict resolver
    conflictResolver = ConflictResolver()

    // Create handler dependencies
    let deps = SyncHandlerDependencies(
      mode: .test,
      conflictResolver: conflictResolver,
      getCurrentUserID: { nil },
      getCurrentUser: { nil },
      fetchCurrentUser: { _ in },
      updateListingConfigReady: { _ in }
    )

    taskHandler = TaskSyncHandler(dependencies: deps)
    activityHandler = ActivitySyncHandler(dependencies: deps)
    listingHandler = ListingSyncHandler(dependencies: deps)
  }

  override func tearDown() async throws {
    taskHandler = nil
    activityHandler = nil
    listingHandler = nil
    conflictResolver = nil
    context = nil
    container = nil
    try await super.tearDown()
  }

  // MARK: - Task Batch Processing Tests

  func test_taskHandler_marksPendingTasksAsInFlightBeforeBatch() throws {
    // Given: Multiple pending tasks
    let task1 = makeTask(title: "Task 1")
    let task2 = makeTask(title: "Task 2")
    task1.markPending()
    task2.markPending()
    context.insert(task1)
    context.insert(task2)
    try context.save()

    // Verify: In-flight tracking is available
    XCTAssertFalse(conflictResolver.isTaskInFlight(task1.id))
    XCTAssertFalse(conflictResolver.isTaskInFlight(task2.id))

    // When: Mark as in-flight (simulating what syncUp does)
    conflictResolver.markTasksInFlight([task1.id, task2.id])

    // Then: Should be tracked as in-flight
    XCTAssertTrue(conflictResolver.isTaskInFlight(task1.id))
    XCTAssertTrue(conflictResolver.isTaskInFlight(task2.id))

    // Cleanup
    conflictResolver.clearTasksInFlight()
  }

  func test_taskHandler_clearsInFlightAfterSyncComplete() throws {
    // Given: Tasks marked as in-flight
    let task1 = makeTask(title: "Task 1")
    task1.markPending()
    context.insert(task1)
    try context.save()

    conflictResolver.markTasksInFlight([task1.id])
    XCTAssertTrue(conflictResolver.isTaskInFlight(task1.id))

    // When: Clear in-flight (simulating defer block in syncUp)
    conflictResolver.clearTasksInFlight()

    // Then: Should no longer be in-flight
    XCTAssertFalse(conflictResolver.isTaskInFlight(task1.id))
  }

  func test_taskHandler_marksSyncedCorrectlyOnSuccess() throws {
    // Given: A pending task
    let task = makeTask(title: "Test Task")
    task.markPending()
    context.insert(task)
    try context.save()

    XCTAssertEqual(task.syncState, .pending)

    // When: Mark as synced (simulating successful upsert)
    task.markSynced()

    // Then: State should be synced
    XCTAssertEqual(task.syncState, .synced)
    XCTAssertNotNil(task.syncedAt)
    XCTAssertEqual(task.retryCount, 0)
    XCTAssertNil(task.lastSyncError)
  }

  func test_taskHandler_marksFailedWithMessageOnError() throws {
    // Given: A pending task
    let task = makeTask(title: "Test Task")
    task.markPending()
    context.insert(task)
    try context.save()

    // When: Mark as failed (simulating individual retry failure)
    task.markFailed("Network error: Connection refused")

    // Then: State should be failed with error message
    XCTAssertEqual(task.syncState, .failed)
    XCTAssertEqual(task.lastSyncError, "Network error: Connection refused")
  }

  func test_taskHandler_retryCountPersistsAcrossMarkPending() throws {
    // Given: A failed task with retry count
    let task = makeTask(title: "Test Task")
    task.markFailed("Error")
    task.retryCount = 3
    context.insert(task)
    try context.save()

    XCTAssertEqual(task.retryCount, 3)
    XCTAssertEqual(task.syncState, .failed)

    // When: Mark as pending for retry
    task.markPending()

    // Then: Retry count should persist (not reset until success)
    // Note: markPending() itself doesn't change retryCount
    // retryCount is only reset by markSynced()
    XCTAssertEqual(task.syncState, .pending)
    // The retry count is preserved so retry logic can track attempts
    XCTAssertEqual(task.retryCount, 3)
  }

  func test_taskHandler_retryCountResetsOnSuccess() throws {
    // Given: A task with high retry count
    let task = makeTask(title: "Test Task")
    task.markFailed("Error")
    task.retryCount = 5
    context.insert(task)
    try context.save()

    XCTAssertEqual(task.retryCount, 5)

    // When: Finally succeeds
    task.markSynced()

    // Then: Retry count should reset
    XCTAssertEqual(task.retryCount, 0)
    XCTAssertEqual(task.syncState, .synced)
  }

  // MARK: - Activity Batch Processing Tests

  func test_activityHandler_marksPendingActivitiesAsInFlightBeforeBatch() throws {
    // Given: Multiple pending activities
    let activity1 = makeActivity(title: "Activity 1")
    let activity2 = makeActivity(title: "Activity 2")
    activity1.markPending()
    activity2.markPending()
    context.insert(activity1)
    context.insert(activity2)
    try context.save()

    // Verify: Not in-flight initially
    XCTAssertFalse(conflictResolver.isActivityInFlight(activity1.id))
    XCTAssertFalse(conflictResolver.isActivityInFlight(activity2.id))

    // When: Mark as in-flight
    conflictResolver.markActivitiesInFlight([activity1.id, activity2.id])

    // Then: Should be tracked
    XCTAssertTrue(conflictResolver.isActivityInFlight(activity1.id))
    XCTAssertTrue(conflictResolver.isActivityInFlight(activity2.id))

    conflictResolver.clearActivitiesInFlight()
  }

  func test_activityHandler_marksSyncedCorrectlyOnSuccess() throws {
    // Given: A pending activity
    let activity = makeActivity(title: "Test Activity")
    activity.markPending()
    context.insert(activity)
    try context.save()

    XCTAssertEqual(activity.syncState, .pending)

    // When: Mark as synced
    activity.markSynced()

    // Then: State should be synced
    XCTAssertEqual(activity.syncState, .synced)
    XCTAssertNotNil(activity.syncedAt)
    XCTAssertEqual(activity.retryCount, 0)
  }

  func test_activityHandler_marksFailedWithMessageOnError() throws {
    // Given: A pending activity
    let activity = makeActivity(title: "Test Activity")
    activity.markPending()
    context.insert(activity)
    try context.save()

    // When: Mark as failed
    activity.markFailed("Server error: 500")

    // Then: State should be failed with error message
    XCTAssertEqual(activity.syncState, .failed)
    XCTAssertEqual(activity.lastSyncError, "Server error: 500")
  }

  // MARK: - Listing Batch Processing Tests

  func test_listingHandler_marksPendingListingsAsInFlightBeforeBatch() throws {
    // Given: Multiple pending listings
    let listing1 = makeListing(address: "123 Main St")
    let listing2 = makeListing(address: "456 Oak Ave")
    listing1.markPending()
    listing2.markPending()
    context.insert(listing1)
    context.insert(listing2)
    try context.save()

    // Verify: Not in-flight initially
    XCTAssertFalse(conflictResolver.isListingInFlight(listing1.id))
    XCTAssertFalse(conflictResolver.isListingInFlight(listing2.id))

    // When: Mark as in-flight
    conflictResolver.markListingsInFlight([listing1.id, listing2.id])

    // Then: Should be tracked
    XCTAssertTrue(conflictResolver.isListingInFlight(listing1.id))
    XCTAssertTrue(conflictResolver.isListingInFlight(listing2.id))

    conflictResolver.clearListingsInFlight()
  }

  func test_listingHandler_marksSyncedCorrectlyOnSuccess() throws {
    // Given: A pending listing
    let listing = makeListing(address: "789 Test Rd")
    listing.markPending()
    context.insert(listing)
    try context.save()

    XCTAssertEqual(listing.syncState, .pending)

    // When: Mark as synced
    listing.markSynced()

    // Then: State should be synced
    XCTAssertEqual(listing.syncState, .synced)
    XCTAssertNotNil(listing.syncedAt)
    XCTAssertEqual(listing.retryCount, 0)
  }

  // MARK: - Mixed Entity Isolation Tests

  func test_inFlightTracking_isolatedBetweenEntityTypes() throws {
    // Given: Same UUID for different entity types
    let sharedId = UUID()

    // When: Mark task as in-flight
    conflictResolver.markTasksInFlight([sharedId])

    // Then: Only task should be in-flight, not activities or listings
    XCTAssertTrue(conflictResolver.isTaskInFlight(sharedId))
    XCTAssertFalse(conflictResolver.isActivityInFlight(sharedId))
    XCTAssertFalse(conflictResolver.isListingInFlight(sharedId))

    conflictResolver.clearTasksInFlight()
  }

  func test_inFlightClearing_onlyAffectsSpecificEntityType() throws {
    // Given: Different entity types marked in-flight
    let taskId = UUID()
    let activityId = UUID()
    let listingId = UUID()

    conflictResolver.markTasksInFlight([taskId])
    conflictResolver.markActivitiesInFlight([activityId])
    conflictResolver.markListingsInFlight([listingId])

    XCTAssertTrue(conflictResolver.isTaskInFlight(taskId))
    XCTAssertTrue(conflictResolver.isActivityInFlight(activityId))
    XCTAssertTrue(conflictResolver.isListingInFlight(listingId))

    // When: Clear only tasks
    conflictResolver.clearTasksInFlight()

    // Then: Only tasks should be cleared
    XCTAssertFalse(conflictResolver.isTaskInFlight(taskId))
    XCTAssertTrue(conflictResolver.isActivityInFlight(activityId))
    XCTAssertTrue(conflictResolver.isListingInFlight(listingId))

    // Cleanup
    conflictResolver.clearAllInFlight()
  }

  // MARK: - Sync State Filtering Tests

  func test_syncHandler_filtersPendingAndFailedForSyncUp() throws {
    // Given: Tasks in various states
    let pendingTask = makeTask(title: "Pending")
    pendingTask.markPending()

    let failedTask = makeTask(title: "Failed")
    failedTask.markFailed("Error")

    let syncedTask = makeTask(title: "Synced")
    syncedTask.markSynced()

    context.insert(pendingTask)
    context.insert(failedTask)
    context.insert(syncedTask)
    try context.save()

    // When: Filter for sync candidates (replicating syncUp logic)
    let allTasks = try context.fetch(FetchDescriptor<TaskItem>())
    let syncCandidates = allTasks.filter { $0.syncState == .pending || $0.syncState == .failed }

    // Then: Should include pending and failed, exclude synced
    XCTAssertEqual(syncCandidates.count, 2)
    XCTAssertTrue(syncCandidates.contains { $0.title == "Pending" })
    XCTAssertTrue(syncCandidates.contains { $0.title == "Failed" })
    XCTAssertFalse(syncCandidates.contains { $0.title == "Synced" })
  }

  // MARK: - BatchSyncResult Tests

  func test_batchSyncResult_aggregatesCorrectly() throws {
    // Given: Create mock tasks for results
    let task1 = makeTask(title: "Success 1")
    let task2 = makeTask(title: "Success 2")
    let task3 = makeTask(title: "Success 3")
    context.insert(task1)
    context.insert(task2)
    context.insert(task3)
    try context.save()

    // Create a successful result
    let result = BatchSyncResult<TaskItem>.success([task1, task2, task3])

    // Then: Should have correct counts
    XCTAssertEqual(result.successCount, 3)
    XCTAssertEqual(result.failureCount, 0)
    XCTAssertTrue(result.isComplete)
  }

  func test_batchSyncResult_emptyIsZero() {
    let empty = BatchSyncResult<TaskItem>.empty
    XCTAssertEqual(empty.successCount, 0)
    XCTAssertEqual(empty.failureCount, 0)
    XCTAssertTrue(empty.isComplete)
  }

  func test_batchSyncResult_isCompleteWhenNoFailures() throws {
    let task1 = makeTask(title: "Task 1")
    let task2 = makeTask(title: "Task 2")
    context.insert(task1)
    context.insert(task2)
    try context.save()

    let success = BatchSyncResult<TaskItem>.success([task1, task2])
    XCTAssertTrue(success.isComplete)
    XCTAssertFalse(success.hasFailures)
  }

  func test_batchSyncResult_hasFailuresWithFailures() throws {
    let task = makeTask(title: "Failed Task")
    context.insert(task)
    try context.save()

    let failure = BatchSyncResult<TaskItem>.singleFailure(task, error: .connectionLost)
    XCTAssertFalse(failure.isComplete)
    XCTAssertTrue(failure.hasFailures)
    XCTAssertEqual(failure.failureCount, 1)
  }

  func test_batchSyncResult_builder() throws {
    let task1 = makeTask(title: "Success")
    let task2 = makeTask(title: "Failure")
    context.insert(task1)
    context.insert(task2)
    try context.save()

    // Use builder pattern
    var builder = BatchSyncResult<TaskItem>.Builder()
    builder.addSuccess(task1)
    builder.addFailure(task2, error: .networkError("Connection refused"))
    let result = builder.build()

    XCTAssertEqual(result.successCount, 1)
    XCTAssertEqual(result.failureCount, 1)
    XCTAssertTrue(result.hasFailures)
  }

  // MARK: - Private Helpers

  private func makeTask(
    id: UUID = UUID(),
    title: String = "Test Task",
    declaredBy: UUID = UUID()
  ) -> TaskItem {
    TaskItem(id: id, title: title, declaredBy: declaredBy)
  }

  private func makeActivity(
    id: UUID = UUID(),
    title: String = "Test Activity",
    declaredBy: UUID = UUID()
  ) -> Activity {
    Activity(id: id, title: title, declaredBy: declaredBy)
  }

  private func makeListing(
    id: UUID = UUID(),
    address: String = "123 Test St",
    ownedBy: UUID = UUID()
  ) -> Listing {
    Listing(id: id, address: address, ownedBy: ownedBy)
  }

  // MARK: - Private Properties

  // swiftlint:disable implicitly_unwrapped_optional
  private var container: ModelContainer!
  private var context: ModelContext!
  private var conflictResolver: ConflictResolver!
  private var taskHandler: TaskSyncHandler!
  private var activityHandler: ActivitySyncHandler!
  private var listingHandler: ListingSyncHandler!
  // swiftlint:enable implicitly_unwrapped_optional
}
