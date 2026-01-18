//
//  RetryCoordinatorTests.swift
//  DispatchTests
//
//  Unit tests for RetryCoordinator extracted from SyncManager.
//  Tests exponential backoff retry logic in isolation.
//

import SwiftData
import XCTest
@testable import DispatchApp

@MainActor
final class RetryCoordinatorTests: XCTestCase {

  // MARK: - Properties

  // swiftlint:disable implicitly_unwrapped_optional
  private var coordinator: RetryCoordinator!
  private var container: ModelContainer!
  // swiftlint:enable implicitly_unwrapped_optional

  // MARK: - Setup / Teardown

  override func setUp() async throws {
    try await super.setUp()
    coordinator = RetryCoordinator(mode: .test)

    // Create in-memory container for testing
    let schema = Schema([
      TaskItem.self,
      Activity.self,
      Listing.self,
      User.self,
      ListingTypeDefinition.self,
      ActivityTemplate.self,
      Property.self,
      Note.self,
      TaskAssignee.self,
      ActivityAssignee.self,
      Subtask.self,
      StatusChange.self,
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    container = try ModelContainer(for: schema, configurations: [config])
  }

  override func tearDown() async throws {
    coordinator = nil
    container = nil
    try await super.tearDown()
  }

  // MARK: - RetryPolicy Tests (Integration)

  func test_retryPolicy_maxRetries_is5() {
    XCTAssertEqual(RetryPolicy.maxRetries, 5)
  }

  func test_retryPolicy_delaySequence() {
    // Verify the exponential backoff sequence: 1, 2, 4, 8, 16, 30 (capped)
    let expected: [TimeInterval] = [1, 2, 4, 8, 16, 30]
    for (attempt, expectedDelay) in expected.enumerated() {
      let actual = RetryPolicy.delay(for: attempt)
      XCTAssertEqual(actual, expectedDelay, accuracy: 0.001,
                     "Attempt \(attempt) should have delay \(expectedDelay)")
    }
  }

  // MARK: - Generic Retry Entity Tests

  func test_retryEntity_incrementsRetryCount() async throws {
    // Create a test task
    let task = TaskItem(
      title: "Test Task",
      declaredBy: UUID()
    )
    task.syncState = .failed
    task.retryCount = 0

    container.mainContext.insert(task)
    try container.mainContext.save()

    var syncCalled = false
    let result = await coordinator.retryEntity(task, entityType: "Task") {
      syncCalled = true
    }

    XCTAssertTrue(result, "Should return true when retry attempted")
    XCTAssertTrue(syncCalled, "Should call sync closure")
    XCTAssertEqual(task.retryCount, 1, "Should increment retry count")
    XCTAssertEqual(task.syncState, .pending, "Should reset state to pending")
    XCTAssertNil(task.lastSyncError, "Should clear last sync error")
  }

  func test_retryEntity_returnsFalseWhenMaxRetriesExceeded() async throws {
    // Create a test task at max retries
    let task = TaskItem(
      title: "Test Task",
      declaredBy: UUID()
    )
    task.syncState = .failed
    task.retryCount = RetryPolicy.maxRetries

    container.mainContext.insert(task)
    try container.mainContext.save()

    var syncCalled = false
    let result = await coordinator.retryEntity(task, entityType: "Task") {
      syncCalled = true
    }

    XCTAssertFalse(result, "Should return false when max retries exceeded")
    XCTAssertFalse(syncCalled, "Should not call sync closure")
    XCTAssertEqual(task.retryCount, RetryPolicy.maxRetries, "Should not change retry count")
    XCTAssertEqual(task.syncState, .failed, "Should remain in failed state")
  }

  // MARK: - Retry Task Tests

  func test_retryTask_delegatesToRetryEntity() async throws {
    let task = TaskItem(
      title: "Test Task",
      declaredBy: UUID()
    )
    task.syncState = .failed
    task.retryCount = 0

    container.mainContext.insert(task)
    try container.mainContext.save()

    var syncCalled = false
    let result = await coordinator.retryTask(task) {
      syncCalled = true
    }

    XCTAssertTrue(result)
    XCTAssertTrue(syncCalled)
    XCTAssertEqual(task.retryCount, 1)
  }

  // MARK: - Retry Activity Tests

  func test_retryActivity_delegatesToRetryEntity() async throws {
    let activity = Activity(
      title: "Test Activity",
      declaredBy: UUID()
    )
    activity.syncState = .failed
    activity.retryCount = 0

    container.mainContext.insert(activity)
    try container.mainContext.save()

    var syncCalled = false
    let result = await coordinator.retryActivity(activity) {
      syncCalled = true
    }

    XCTAssertTrue(result)
    XCTAssertTrue(syncCalled)
    XCTAssertEqual(activity.retryCount, 1)
  }

  // MARK: - Retry Listing Tests

  func test_retryListing_delegatesToRetryEntity() async throws {
    let listing = Listing(
      address: "123 Test St",
      ownedBy: UUID()
    )
    listing.syncState = .failed
    listing.retryCount = 0

    container.mainContext.insert(listing)
    try container.mainContext.save()

    var syncCalled = false
    let result = await coordinator.retryListing(listing) {
      syncCalled = true
    }

    XCTAssertTrue(result)
    XCTAssertTrue(syncCalled)
    XCTAssertEqual(listing.retryCount, 1)
  }

  // MARK: - Retry Failed Entities Tests

  func test_retryFailedEntities_findsAndRetriesFailedTasks() async throws {
    // Create a failed task
    let task = TaskItem(
      title: "Failed Task",
      declaredBy: UUID()
    )
    task.syncState = .failed
    task.retryCount = 0

    // Create a synced task (should not be retried)
    let syncedTask = TaskItem(
      title: "Synced Task",
      declaredBy: UUID()
    )
    syncedTask.syncState = .synced
    syncedTask.retryCount = 0

    container.mainContext.insert(task)
    container.mainContext.insert(syncedTask)
    try container.mainContext.save()

    var syncCalled = false
    await coordinator.retryFailedEntities(container: container) {
      syncCalled = true
    }

    XCTAssertTrue(syncCalled, "Should call sync for failed entities")
    XCTAssertEqual(task.retryCount, 1, "Failed task retry count should increment")
    XCTAssertEqual(task.syncState, .pending, "Failed task should be set to pending")
    XCTAssertEqual(syncedTask.retryCount, 0, "Synced task should not be affected")
  }

  func test_retryFailedEntities_skipsMaxedOutEntities() async throws {
    // Create a failed task at max retries
    let maxedTask = TaskItem(
      title: "Maxed Task",
      declaredBy: UUID()
    )
    maxedTask.syncState = .failed
    maxedTask.retryCount = RetryPolicy.maxRetries

    // Create a failed task that can be retried
    let retriableTask = TaskItem(
      title: "Retriable Task",
      declaredBy: UUID()
    )
    retriableTask.syncState = .failed
    retriableTask.retryCount = 1

    container.mainContext.insert(maxedTask)
    container.mainContext.insert(retriableTask)
    try container.mainContext.save()

    var syncCalled = false
    await coordinator.retryFailedEntities(container: container) {
      syncCalled = true
    }

    XCTAssertTrue(syncCalled)
    XCTAssertEqual(maxedTask.retryCount, RetryPolicy.maxRetries, "Maxed task should not change")
    XCTAssertEqual(maxedTask.syncState, .failed, "Maxed task should stay failed")
    XCTAssertEqual(retriableTask.retryCount, 2, "Retriable task should increment")
    XCTAssertEqual(retriableTask.syncState, .pending, "Retriable task should be pending")
  }

  func test_retryFailedEntities_noFailedEntities_doesNotSync() async throws {
    // Create only synced tasks
    let task = TaskItem(
      title: "Synced Task",
      declaredBy: UUID()
    )
    task.syncState = .synced

    container.mainContext.insert(task)
    try container.mainContext.save()

    var syncCalled = false
    await coordinator.retryFailedEntities(container: container) {
      syncCalled = true
    }

    XCTAssertFalse(syncCalled, "Should not sync when no failed entities")
  }

  func test_retryFailedEntities_allMaxedOut_doesNotSync() async throws {
    // Create only maxed out tasks
    let task = TaskItem(
      title: "Maxed Task",
      declaredBy: UUID()
    )
    task.syncState = .failed
    task.retryCount = RetryPolicy.maxRetries

    container.mainContext.insert(task)
    try container.mainContext.save()

    var syncCalled = false
    await coordinator.retryFailedEntities(container: container) {
      syncCalled = true
    }

    XCTAssertFalse(syncCalled, "Should not sync when all failed entities are maxed out")
  }

  // MARK: - Mode Tests

  func test_testMode_skipsBackoffDelay() async throws {
    // In test mode, backoff delay should be skipped
    let coordinator = RetryCoordinator(mode: .test)

    let task = TaskItem(
      title: "Test Task",
      declaredBy: UUID()
    )
    task.syncState = .failed
    task.retryCount = 4 // Would normally have 16s delay

    container.mainContext.insert(task)
    try container.mainContext.save()

    let start = Date()
    var syncCalled = false
    _ = await coordinator.retryEntity(task, entityType: "Task") {
      syncCalled = true
    }
    let elapsed = Date().timeIntervalSince(start)

    XCTAssertTrue(syncCalled)
    // In test mode, should be nearly instant (no 16s delay)
    XCTAssertLessThan(elapsed, 1.0, "Test mode should skip backoff delay")
  }
}
