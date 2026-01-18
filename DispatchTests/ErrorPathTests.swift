//
//  ErrorPathTests.swift
//  DispatchTests
//
//  Tests for error handling paths in the sync system.
//  Covers: retry exhaustion, error message mapping, graceful degradation.
//

import SwiftData
import XCTest
@testable import DispatchApp

// MARK: - ErrorPathTests

@MainActor
final class ErrorPathTests: XCTestCase {

  // swiftlint:disable implicitly_unwrapped_optional
  var container: ModelContainer!
  var context: ModelContext!
  var syncManager: SyncManager!

  // swiftlint:enable implicitly_unwrapped_optional

  override func setUp() async throws {
    // Use in-memory container for speed and isolation
    let schema = Schema([
      User.self,
      Listing.self,
      TaskItem.self,
      Activity.self,
      Note.self,
      StatusChange.self,
      Subtask.self,
      TaskAssignee.self,
      ActivityAssignee.self,
      ActivityTemplate.self,
      ListingTypeDefinition.self,
      Property.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    container = try ModelContainer(for: schema, configurations: config)
    context = container.mainContext

    // Initialize SyncManager in test mode for isolation
    syncManager = SyncManager(mode: .test)
    syncManager.configure(with: container)
  }

  override func tearDown() async throws {
    await syncManager.shutdown()
    container = nil
    context = nil
    syncManager = nil
  }

  // MARK: - Retry Exhaustion Tests

  /// Test that retryTask returns false when max retries have been exceeded
  func testRetryExhaustion_WhenMaxRetriesReached_ReturnsFalse() async throws {
    // Create a TaskItem with retryCount at maximum
    let userId = UUID()
    let task = TaskItem(
      id: UUID(),
      title: "Test Task",
      taskDescription: "A task that has exhausted retries",
      declaredBy: userId
    )
    task.retryCount = RetryPolicy.maxRetries // Set to 5
    task.syncState = .failed
    task.lastSyncError = "Previous sync error"
    context.insert(task)
    try context.save()

    // Attempt retry - should return false immediately
    let result = await syncManager.retryTask(task)

    // Verify: retry should be rejected
    XCTAssertFalse(result, "retryTask should return false when max retries exceeded")
  }

  /// Test that entity stays in .failed state after retry exhaustion
  func testRetryExhaustion_EntityStaysInFailedState() async throws {
    let userId = UUID()
    let task = TaskItem(
      id: UUID(),
      title: "Exhausted Task",
      taskDescription: "Should remain failed",
      declaredBy: userId
    )
    task.retryCount = RetryPolicy.maxRetries
    task.syncState = .failed
    task.lastSyncError = "Network error"
    context.insert(task)
    try context.save()

    // Attempt retry
    _ = await syncManager.retryTask(task)

    // Verify: entity should still be in .failed state
    XCTAssertEqual(task.syncState, .failed, "Entity should remain in .failed state")
    XCTAssertEqual(task.retryCount, RetryPolicy.maxRetries, "Retry count should not be incremented beyond max")
  }

  /// Test retry exhaustion for Activity entities
  func testRetryExhaustion_Activity_ReturnsFalse() async throws {
    let userId = UUID()
    let activity = Activity(
      id: UUID(),
      title: "Test Activity",
      activityDescription: "Activity with exhausted retries",
      dueDate: Date(),
      declaredBy: userId
    )
    activity.retryCount = RetryPolicy.maxRetries
    activity.syncState = .failed
    context.insert(activity)
    try context.save()

    let result = await syncManager.retryActivity(activity)

    XCTAssertFalse(result, "retryActivity should return false when max retries exceeded")
    XCTAssertEqual(activity.syncState, .failed, "Activity should remain failed")
  }

  /// Test retry exhaustion for Listing entities
  func testRetryExhaustion_Listing_ReturnsFalse() async throws {
    let userId = UUID()
    let listing = Listing(
      id: UUID(),
      address: "123 Retry Failed St",
      ownedBy: userId
    )
    listing.retryCount = RetryPolicy.maxRetries
    listing.syncState = .failed
    context.insert(listing)
    try context.save()

    let result = await syncManager.retryListing(listing)

    XCTAssertFalse(result, "retryListing should return false when max retries exceeded")
    XCTAssertEqual(listing.syncState, .failed, "Listing should remain failed")
  }

  /// Test that entities with retryCount below max are still eligible for retry
  func testRetryEligible_WhenBelowMaxRetries() async throws {
    let userId = UUID()
    let task = TaskItem(
      id: UUID(),
      title: "Retriable Task",
      taskDescription: "Should be eligible for retry",
      declaredBy: userId
    )
    task.retryCount = RetryPolicy.maxRetries - 1 // One below max (4)
    task.syncState = .failed
    context.insert(task)
    try context.save()

    // Store initial state
    let initialRetryCount = task.retryCount

    // Verify precondition
    XCTAssertTrue(
      task.retryCount < RetryPolicy.maxRetries,
      "Precondition: retryCount should be below max"
    )

    // Act: Attempt retry
    let result = await syncManager.retryTask(task)

    // Assert: Retry should succeed
    XCTAssertTrue(result, "retryTask should return true when below max retries")
    XCTAssertEqual(
      task.retryCount,
      initialRetryCount + 1,
      "retryCount should increment from \(initialRetryCount) to \(initialRetryCount + 1)"
    )
    XCTAssertEqual(task.syncState, .pending, "syncState should transition to .pending for retry")
  }

  // MARK: - Error Message Mapping Tests

  /// Test that network timeout produces correct user-facing message
  func testNetworkTimeout_ProducesCorrectErrorMessage() {
    let error = URLError(.timedOut)
    let message = userFacingMessage(for: error)

    XCTAssertEqual(message, "Connection timed out.", "Timeout should produce friendly message")
  }

  /// Test that no internet connection produces correct error message
  func testNoInternetConnection_ProducesCorrectErrorMessage() {
    let error = URLError(.notConnectedToInternet)
    let message = userFacingMessage(for: error)

    XCTAssertEqual(message, "No internet connection.", "No internet should produce friendly message")
  }

  /// Test that network connection lost produces correct error message
  func testNetworkConnectionLost_ProducesCorrectErrorMessage() {
    let error = URLError(.networkConnectionLost)
    let message = userFacingMessage(for: error)

    XCTAssertEqual(message, "No internet connection.", "Connection lost should produce friendly message")
  }

  /// Test that generic URLError produces network error message
  func testGenericURLError_ProducesNetworkErrorMessage() {
    let error = URLError(.cannotFindHost)
    let message = userFacingMessage(for: error)

    XCTAssertEqual(message, "Network error.", "Unknown URLError should produce generic network error")
  }

  /// Test permission denied (42501) produces correct message
  func testPermissionDenied_42501_ProducesCorrectErrorMessage() {
    // Create a mock error that contains the PostgreSQL error code
    let mockError = MockPostgresError(code: "42501", message: "permission denied for table tasks")
    let message = userFacingMessage(for: mockError)

    XCTAssertTrue(
      message.contains("Permission denied"),
      "42501 error should produce permission denied message"
    )
  }

  /// Test permission denied for notes table produces specific message
  func testPermissionDenied_Notes_ProducesSpecificMessage() {
    let mockError = MockPostgresError(code: "42501", message: "permission denied for table notes")
    let message = userFacingMessage(for: mockError)

    XCTAssertEqual(
      message,
      "Permission denied syncing notes.",
      "Notes permission error should be specific"
    )
  }

  /// Test permission denied for listings table produces specific message
  func testPermissionDenied_Listings_ProducesSpecificMessage() {
    let mockError = MockPostgresError(code: "42501", message: "permission denied for table listings")
    let message = userFacingMessage(for: mockError)

    XCTAssertEqual(
      message,
      "Permission denied syncing listings.",
      "Listings permission error should be specific"
    )
  }

  /// Test permission denied for tasks table produces specific message
  func testPermissionDenied_Tasks_ProducesSpecificMessage() {
    let mockError = MockPostgresError(code: "42501", message: "permission denied for table tasks")
    let message = userFacingMessage(for: mockError)

    XCTAssertEqual(
      message,
      "Permission denied syncing tasks.",
      "Tasks permission error should be specific"
    )
  }

  /// Test permission denied for activities table produces specific message
  func testPermissionDenied_Activities_ProducesSpecificMessage() {
    let mockError = MockPostgresError(code: "42501", message: "permission denied for table activities")
    let message = userFacingMessage(for: mockError)

    XCTAssertEqual(
      message,
      "Permission denied syncing activities.",
      "Activities permission error should be specific"
    )
  }

  /// Test permission denied for users table produces specific message
  func testPermissionDenied_Users_ProducesSpecificMessage() {
    let mockError = MockPostgresError(code: "42501", message: "permission denied for table users")
    let message = userFacingMessage(for: mockError)

    XCTAssertEqual(
      message,
      "Permission denied syncing user profile.",
      "Users permission error should be specific"
    )
  }

  /// Test generic permission denied produces generic message
  func testPermissionDenied_Generic_ProducesGenericMessage() {
    let mockError = MockPostgresError(code: "42501", message: "permission denied")
    let message = userFacingMessage(for: mockError)

    XCTAssertEqual(
      message,
      "Permission denied during sync.",
      "Generic permission error should produce generic message"
    )
  }

  /// Test unknown error produces fallback message
  func testUnknownError_ProducesFallbackMessage() {
    let error = MockGenericError(message: "Something unexpected happened")
    let message = userFacingMessage(for: error)

    XCTAssertTrue(
      message.starts(with: "Sync failed:"),
      "Unknown error should produce fallback message"
    )
  }

  // MARK: - Graceful Degradation Tests

  /// Test that SyncManager initializes correctly in test mode
  func testSyncManager_InitializesInTestMode() async {
    let manager = SyncManager(mode: .test)
    XCTAssertEqual(manager.mode, .test, "Manager should be in test mode")
    XCTAssertEqual(manager.syncStatus, .idle, "Initial status should be idle")
    await manager.shutdown()
  }

  /// Test that sync manager handles missing container gracefully
  func testSyncManager_HandlesMissingContainer() async {
    let manager = SyncManager(mode: .test)
    // Don't configure with container

    // This should not crash - just return early
    await manager.sync()

    // Manager should still be in a valid state
    XCTAssertEqual(manager.syncStatus, .idle, "Status should remain idle without container")
  }

  /// Test that sync manager handles missing authentication gracefully
  func testSyncManager_HandlesMissingAuthentication() async {
    let manager = SyncManager(mode: .test)
    manager.configure(with: container)
    // Don't set currentUserID

    await manager.sync()

    // Should not crash, should be idle
    XCTAssertEqual(manager.syncStatus, .idle, "Status should be idle without auth")
    await manager.shutdown()
  }

  /// Test that retry counts are persisted on entities
  func testRetryCount_PersistedOnEntity() async throws {
    let userId = UUID()
    let task = TaskItem(
      id: UUID(),
      title: "Persistent Retry Task",
      taskDescription: "Retry count should persist",
      declaredBy: userId
    )
    task.retryCount = 3
    context.insert(task)
    try context.save()

    // Fetch the task back
    let taskId = task.id
    let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskId })
    let fetchedTask = try context.fetch(descriptor).first

    XCTAssertNotNil(fetchedTask, "Task should be fetchable")
    XCTAssertEqual(fetchedTask?.retryCount, 3, "Retry count should be persisted")
  }

  /// Test that markSynced resets retry count
  func testMarkSynced_ResetsRetryCount() async throws {
    let userId = UUID()
    let task = TaskItem(
      id: UUID(),
      title: "Reset Retry Task",
      declaredBy: userId
    )
    task.retryCount = 4
    task.syncState = .pending

    task.markSynced()

    XCTAssertEqual(task.retryCount, 0, "markSynced should reset retry count")
    XCTAssertEqual(task.syncState, .synced, "State should be synced")
  }

  /// Test that markFailed preserves retry count
  func testMarkFailed_PreservesRetryCount() async throws {
    let userId = UUID()
    let task = TaskItem(
      id: UUID(),
      title: "Failed Retry Task",
      declaredBy: userId
    )
    task.retryCount = 3

    task.markFailed("Test error")

    XCTAssertEqual(task.retryCount, 3, "markFailed should preserve retry count")
    XCTAssertEqual(task.syncState, .failed, "State should be failed")
    XCTAssertEqual(task.lastSyncError, "Test error", "Error message should be set")
  }

  // MARK: - RetryPolicy Constants Tests

  /// Verify RetryPolicy constants match expected values
  func testRetryPolicy_Constants() {
    XCTAssertEqual(RetryPolicy.maxRetries, 5, "Max retries should be 5")
    XCTAssertEqual(RetryPolicy.maxDelay, 30.0, "Max delay should be 30 seconds")
  }

  /// Test exponential backoff sequence
  func testRetryPolicy_ExponentialBackoff() {
    let expectedDelays: [TimeInterval] = [1, 2, 4, 8, 16, 30]

    for (attempt, expectedDelay) in expectedDelays.enumerated() {
      let actualDelay = RetryPolicy.delay(for: attempt)
      XCTAssertEqual(
        actualDelay,
        expectedDelay,
        accuracy: 0.001,
        "Attempt \(attempt) should have delay \(expectedDelay)s"
      )
    }
  }

}

// MARK: - MockPostgresError

/// Mock error that simulates a PostgreSQL error with code
struct MockPostgresError: Error, CustomStringConvertible {
  let code: String
  let message: String

  var description: String {
    "PostgrestError(code: \(code), message: \(message))"
  }
}

// MARK: - MockGenericError

/// Generic mock error for testing fallback behavior
struct MockGenericError: Error, LocalizedError {
  let message: String

  var errorDescription: String? {
    message
  }
}
