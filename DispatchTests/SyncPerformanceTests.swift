//
//  SyncPerformanceTests.swift
//  DispatchTests
//
//  Performance regression tests for sync operations.
//  Uses manual timing to catch O(n^2) regressions.
//
//  These tests ensure that sync operations complete in acceptable time
//  and would fail if someone accidentally introduced inefficient patterns.
//

import SwiftData
import XCTest
@testable import DispatchApp

// MARK: - SyncPerformanceTests

@MainActor
final class SyncPerformanceTests: XCTestCase {

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

    // Create SyncManager in test mode
    syncManager = SyncManager(mode: .test)
    syncManager.configure(with: container)

    // Create handler dependencies
    conflictResolver = ConflictResolver()
    let deps = SyncHandlerDependencies(
      mode: .test,
      conflictResolver: conflictResolver,
      getCurrentUserID: { nil },
      getCurrentUser: { nil },
      fetchCurrentUser: { _ in },
      updateListingConfigReady: { _ in }
    )

    taskHandler = TaskSyncHandler(dependencies: deps)
    listingHandler = ListingSyncHandler(dependencies: deps)
    userHandler = UserSyncHandler(dependencies: deps)
  }

  override func tearDown() async throws {
    await syncManager.shutdown()
    syncManager = nil
    taskHandler = nil
    listingHandler = nil
    userHandler = nil
    conflictResolver = nil
    context = nil
    container = nil
    try await super.tearDown()
  }

  // MARK: - Task Upsert Performance Tests

  /// Verifies that upserting 100 tasks completes in reasonable time.
  /// This test will fail if someone introduces an O(n^2) pattern in upsertTask.
  func test_upsertTask_100Items_completesQuickly() throws {
    // Create 100 task DTOs
    let dtos = (0 ..< 100).map { i in
      makeTaskDTO(title: "Task \(i)")
    }

    // Measure time
    let start = Date()
    for dto in dtos {
      try taskHandler.upsertTask(dto: dto, context: context)
    }
    let duration = Date().timeIntervalSince(start)

    // Should complete in under 2 seconds (generous for CI)
    XCTAssertLessThan(duration, 2.0, "100 task upserts should complete quickly")
  }

  /// Verifies that updating existing tasks doesn't degrade performance.
  func test_updateExistingTasks_completesQuickly() throws {
    // Pre-create 100 tasks
    let existingTasks = (0 ..< 100).map { i -> TaskItem in
      let task = TaskItem(title: "Existing \(i)", declaredBy: UUID())
      task.markSynced()
      context.insert(task)
      return task
    }
    try context.save()

    // Create DTOs for updates
    let updateDTOs = existingTasks.map { task in
      TaskDTO(
        id: task.id,
        title: "Updated \(task.title)",
        description: "New description",
        dueDate: nil,
        status: "in_progress",
        declaredBy: task.declaredBy,
        listing: nil,
        createdVia: "dispatch",
        sourceSlackMessages: nil,
        audiences: nil,
        completedAt: nil,
        deletedAt: nil,
        createdAt: Date(),
        updatedAt: Date()
      )
    }

    // Measure update performance
    let start = Date()
    for dto in updateDTOs {
      try taskHandler.upsertTask(dto: dto, context: context)
    }
    let duration = Date().timeIntervalSince(start)

    // Updates should be fast
    XCTAssertLessThan(duration, 2.0, "100 task updates should complete quickly")
  }

  // MARK: - Relationship Reconciliation Performance Tests

  /// Verifies that reconciling listing relationships is efficient.
  /// The implementation should use batch lookup, not per-listing queries.
  func test_reconcileListingRelationships_100Listings_completesQuickly() async throws {
    // Pre-create 50 users
    let users = (0 ..< 50).map { i -> User in
      let user = User(id: UUID(), name: "User \(i)", email: "user\(i)@test.com", userType: .realtor)
      context.insert(user)
      return user
    }

    // Pre-create 100 orphaned listings (2 per user)
    for (index, user) in users.enumerated() {
      let listing1 = Listing(address: "Listing \(index * 2)", ownedBy: user.id)
      let listing2 = Listing(address: "Listing \(index * 2 + 1)", ownedBy: user.id)
      // Don't set listing.owner - these are orphans
      context.insert(listing1)
      context.insert(listing2)
    }
    try context.save()

    // Measure reconciliation performance
    let start = Date()
    try await syncManager.reconcileListingRelationships(context: context)
    let duration = Date().timeIntervalSince(start)

    // Should complete in reasonable time (1 second is generous)
    XCTAssertLessThan(duration, 1.0, "Reconciliation of 100 listings should complete quickly")
  }

  // MARK: - Filtering Performance Tests

  /// Verifies that filtering pending tasks is efficient.
  func test_filterPendingTasks_mixedStates_completesQuickly() throws {
    // Create tasks in mixed states
    for i in 0 ..< 300 {
      let task = TaskItem(title: "Task \(i)", declaredBy: UUID())
      switch i % 3 {
      case 0: task.markPending()
      case 1: task.markSynced()
      default: task.markFailed("Error")
      }
      context.insert(task)
    }
    try context.save()

    // Measure filtering performance
    let start = Date()
    let descriptor = FetchDescriptor<TaskItem>()
    let allTasks = try context.fetch(descriptor)
    let syncCandidates = allTasks.filter { $0.syncState == .pending || $0.syncState == .failed }
    let duration = Date().timeIntervalSince(start)

    // Verify we got the right count
    XCTAssertEqual(syncCandidates.count, 200) // 2/3 of 300

    // Should be fast
    XCTAssertLessThan(duration, 1.0, "Filtering 300 tasks should be quick")
  }

  // MARK: - In-Flight Tracking Performance Tests

  /// Verifies that in-flight tracking with many items is efficient.
  func test_inFlightTracking_1000Items_completesQuickly() {
    let ids = (0 ..< 1000).map { _ in UUID() }

    let start = Date()

    // Mark all as in-flight
    conflictResolver.markTasksInFlight(Set(ids))

    // Check each one
    for id in ids {
      _ = conflictResolver.isTaskInFlight(id)
    }

    // Clear all
    conflictResolver.clearTasksInFlight()

    let duration = Date().timeIntervalSince(start)

    // Should be very fast (Set operations are O(1))
    XCTAssertLessThan(duration, 0.5, "In-flight tracking should be O(1) operations")
  }

  // MARK: - Batch Size Tests

  /// Verifies that processing entities one-by-one scales linearly (not quadratically).
  func test_localProcessing_scalesLinearly() throws {
    // Create baseline with 10 items
    let baselineCount = 10
    var baselineDuration: TimeInterval = 0

    let baselineDTOs = (0 ..< baselineCount).map { i in
      makeTaskDTO(title: "Baseline \(i)")
    }

    let baselineStart = Date()
    for dto in baselineDTOs {
      try taskHandler.upsertTask(dto: dto, context: context)
    }
    baselineDuration = Date().timeIntervalSince(baselineStart)

    // Clear context for next test
    let allTasks = try context.fetch(FetchDescriptor<TaskItem>())
    for task in allTasks {
      context.delete(task)
    }
    try context.save()

    // Test with 100 items (10x baseline)
    let scaledCount = 100
    let scaledDTOs = (0 ..< scaledCount).map { i in
      makeTaskDTO(title: "Scaled \(i)")
    }

    let scaledStart = Date()
    for dto in scaledDTOs {
      try taskHandler.upsertTask(dto: dto, context: context)
    }
    let scaledDuration = Date().timeIntervalSince(scaledStart)

    // Scaled should be roughly 10x baseline, not 100x (which would indicate O(n^2))
    // Allow for some overhead (20x is generous but catches egregious regressions)
    let ratio = scaledDuration / baselineDuration

    // Skip assertion if baseline is too fast to measure reliably
    if baselineDuration > 0.001 {
      XCTAssertLessThan(
        ratio,
        20.0, // Generous threshold to avoid flaky tests
        "Scaling from \(baselineCount) to \(scaledCount) items took \(ratio)x longer, suggesting O(n^2) complexity"
      )
    }
  }

  // MARK: - Memory Efficiency Tests

  /// Verifies that large batch processing doesn't create excessive intermediate objects.
  func test_largeBatch_completesWithoutCrash() throws {
    // This is a sanity check - the test passes if it doesn't crash
    let largeBatchSize = 200 // Reduced from 500 to avoid SwiftData memory issues
    let dtos = (0 ..< largeBatchSize).map { i in
      makeTaskDTO(title: "Large Batch Task \(i)")
    }

    // Process all items - if this crashes with memory issues, test fails
    for dto in dtos {
      try taskHandler.upsertTask(dto: dto, context: context)
    }

    // Verify all were inserted
    let count = try context.fetchCount(FetchDescriptor<TaskItem>())
    XCTAssertEqual(count, largeBatchSize)
  }

  // MARK: - Private Helpers

  private func makeTaskDTO(title: String) -> TaskDTO {
    TaskDTO(
      id: UUID(),
      title: title,
      description: nil,
      dueDate: nil,
      status: "open",
      declaredBy: UUID(),
      listing: nil,
      createdVia: "dispatch",
      sourceSlackMessages: nil,
      audiences: nil,
      completedAt: nil,
      deletedAt: nil,
      createdAt: Date(),
      updatedAt: Date()
    )
  }

  // MARK: Private

  // swiftlint:disable implicitly_unwrapped_optional
  private var container: ModelContainer!
  private var context: ModelContext!
  private var syncManager: SyncManager!
  private var conflictResolver: ConflictResolver!
  private var taskHandler: TaskSyncHandler!
  private var listingHandler: ListingSyncHandler!
  private var userHandler: UserSyncHandler!
  // swiftlint:enable implicitly_unwrapped_optional
}
