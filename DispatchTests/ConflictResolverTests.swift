//
//  ConflictResolverTests.swift
//  DispatchTests
//
//  Tests for ConflictResolver in-flight tracking and conflict resolution logic.
//

import XCTest
@testable import DispatchApp

// MARK: - MockSyncable

/// Minimal mock for testing isLocalAuthoritative
private struct MockSyncable: RealtimeSyncable {
  var syncedAt: Date?
  var syncState: EntitySyncState
  var lastSyncError: String?
  var conflictResolution: ConflictStrategy { .lastWriteWins }
}

// MARK: - ConflictResolverTests

@MainActor
final class ConflictResolverTests: XCTestCase {

  // MARK: Internal

  override func setUp() {
    super.setUp()
    resolver = ConflictResolver()
  }

  // MARK: - Task In-Flight Tracking

  func test_markTasksInFlight_addsIds() {
    let id1 = UUID()
    let id2 = UUID()

    resolver.markTasksInFlight([id1, id2])

    XCTAssertTrue(resolver.isTaskInFlight(id1))
    XCTAssertTrue(resolver.isTaskInFlight(id2))
  }

  func test_isTaskInFlight_returnsFalseForUnmarkedId() {
    let markedId = UUID()
    let unmarkedId = UUID()

    resolver.markTasksInFlight([markedId])

    XCTAssertFalse(resolver.isTaskInFlight(unmarkedId))
  }

  func test_clearTasksInFlight_removesAllTaskIds() {
    let id1 = UUID()
    let id2 = UUID()
    resolver.markTasksInFlight([id1, id2])

    resolver.clearTasksInFlight()

    XCTAssertFalse(resolver.isTaskInFlight(id1))
    XCTAssertFalse(resolver.isTaskInFlight(id2))
    XCTAssertTrue(resolver.inFlightTaskIds.isEmpty)
  }

  func test_markTasksInFlight_replacesExistingIds() {
    let oldId = UUID()
    let newId = UUID()

    resolver.markTasksInFlight([oldId])
    resolver.markTasksInFlight([newId])

    XCTAssertFalse(resolver.isTaskInFlight(oldId), "Old ID should be replaced")
    XCTAssertTrue(resolver.isTaskInFlight(newId), "New ID should be present")
  }

  // MARK: - Activity In-Flight Tracking

  func test_markActivitiesInFlight_addsIds() {
    let id1 = UUID()
    let id2 = UUID()

    resolver.markActivitiesInFlight([id1, id2])

    XCTAssertTrue(resolver.isActivityInFlight(id1))
    XCTAssertTrue(resolver.isActivityInFlight(id2))
  }

  func test_isActivityInFlight_returnsFalseForUnmarkedId() {
    let markedId = UUID()
    let unmarkedId = UUID()

    resolver.markActivitiesInFlight([markedId])

    XCTAssertFalse(resolver.isActivityInFlight(unmarkedId))
  }

  func test_clearActivitiesInFlight_removesAllActivityIds() {
    let id1 = UUID()
    let id2 = UUID()
    resolver.markActivitiesInFlight([id1, id2])

    resolver.clearActivitiesInFlight()

    XCTAssertFalse(resolver.isActivityInFlight(id1))
    XCTAssertFalse(resolver.isActivityInFlight(id2))
    XCTAssertTrue(resolver.inFlightActivityIds.isEmpty)
  }

  // MARK: - Note In-Flight Tracking

  func test_markNotesInFlight_addsIds() {
    let id1 = UUID()
    let id2 = UUID()

    resolver.markNotesInFlight([id1, id2])

    XCTAssertTrue(resolver.isNoteInFlight(id1))
    XCTAssertTrue(resolver.isNoteInFlight(id2))
  }

  func test_isNoteInFlight_returnsFalseForUnmarkedId() {
    let markedId = UUID()
    let unmarkedId = UUID()

    resolver.markNotesInFlight([markedId])

    XCTAssertFalse(resolver.isNoteInFlight(unmarkedId))
  }

  func test_clearNotesInFlight_removesAllNoteIds() {
    let id1 = UUID()
    let id2 = UUID()
    resolver.markNotesInFlight([id1, id2])

    resolver.clearNotesInFlight()

    XCTAssertFalse(resolver.isNoteInFlight(id1))
    XCTAssertFalse(resolver.isNoteInFlight(id2))
    XCTAssertTrue(resolver.inFlightNoteIds.isEmpty)
  }

  // MARK: - Clear All In-Flight

  func test_clearAllInFlight_clearsAllEntityTypes() {
    let taskId = UUID()
    let activityId = UUID()
    let noteId = UUID()

    resolver.markTasksInFlight([taskId])
    resolver.markActivitiesInFlight([activityId])
    resolver.markNotesInFlight([noteId])

    resolver.clearAllInFlight()

    XCTAssertTrue(resolver.inFlightTaskIds.isEmpty, "Task IDs should be cleared")
    XCTAssertTrue(resolver.inFlightActivityIds.isEmpty, "Activity IDs should be cleared")
    XCTAssertTrue(resolver.inFlightNoteIds.isEmpty, "Note IDs should be cleared")
  }

  // MARK: - isLocalAuthoritative Tests

  func test_isLocalAuthoritative_returnsTrueWhenPending() {
    let model = MockSyncable(syncedAt: nil, syncState: .pending, lastSyncError: nil)

    let result = resolver.isLocalAuthoritative(model, inFlight: false)

    XCTAssertTrue(result, "Pending entities should be local-authoritative")
  }

  func test_isLocalAuthoritative_returnsTrueWhenFailed() {
    let model = MockSyncable(syncedAt: nil, syncState: .failed, lastSyncError: "Network error")

    let result = resolver.isLocalAuthoritative(model, inFlight: false)

    XCTAssertTrue(result, "Failed entities should be local-authoritative")
  }

  func test_isLocalAuthoritative_returnsTrueWhenInFlight() {
    let model = MockSyncable(syncedAt: Date(), syncState: .synced, lastSyncError: nil)

    let result = resolver.isLocalAuthoritative(model, inFlight: true)

    XCTAssertTrue(result, "In-flight entities should be local-authoritative")
  }

  func test_isLocalAuthoritative_returnsFalseWhenSyncedAndNotInFlight() {
    let model = MockSyncable(syncedAt: Date(), syncState: .synced, lastSyncError: nil)

    let result = resolver.isLocalAuthoritative(model, inFlight: false)

    XCTAssertFalse(result, "Synced entities not in-flight should NOT be local-authoritative")
  }

  func test_isLocalAuthoritative_pendingAndInFlight_returnsTrue() {
    let model = MockSyncable(syncedAt: nil, syncState: .pending, lastSyncError: nil)

    let result = resolver.isLocalAuthoritative(model, inFlight: true)

    XCTAssertTrue(result, "Pending + in-flight should be local-authoritative")
  }

  func test_isLocalAuthoritative_failedAndInFlight_returnsTrue() {
    let model = MockSyncable(syncedAt: nil, syncState: .failed, lastSyncError: "Error")

    let result = resolver.isLocalAuthoritative(model, inFlight: true)

    XCTAssertTrue(result, "Failed + in-flight should be local-authoritative")
  }

  // MARK: - Concurrent Access Tests

  func test_concurrentAccess_multipleMarkOperationsPreserveIsolation() async {
    // Verify that multiple async operations on the MainActor resolver
    // maintain consistent state (no data races)
    let taskIds1 = Set((0 ..< 10).map { _ in UUID() })
    let taskIds2 = Set((0 ..< 10).map { _ in UUID() })

    // Simulate concurrent mark operations
    async let mark1: Void = Task { @MainActor in
      resolver.markTasksInFlight(taskIds1)
    }.value

    async let mark2: Void = Task { @MainActor in
      // Small yield to create interleaving opportunity
      await Task.yield()
      resolver.markTasksInFlight(taskIds2)
    }.value

    _ = await (mark1, mark2)

    // After both complete, only the second set should be present
    // (markTasksInFlight replaces, not merges)
    for id in taskIds2 {
      XCTAssertTrue(resolver.isTaskInFlight(id), "Second set should be present")
    }
  }

  func test_concurrentAccess_clearWhileCheckingDoesNotCrash() async {
    let ids = Set((0 ..< 100).map { _ in UUID() })
    resolver.markTasksInFlight(ids)

    // Run clear and checks concurrently - should not crash due to MainActor serialization
    async let clear: Void = Task { @MainActor in
      resolver.clearTasksInFlight()
    }.value

    async let checks: [Bool] = Task { @MainActor in
      ids.map { resolver.isTaskInFlight($0) }
    }.value

    _ = await (clear, checks)

    // After serialization, all should be cleared
    XCTAssertTrue(resolver.inFlightTaskIds.isEmpty)
  }

  func test_entityTypesAreIsolated() {
    let sharedId = UUID()

    resolver.markTasksInFlight([sharedId])

    // Same UUID should not appear in other entity type sets
    XCTAssertTrue(resolver.isTaskInFlight(sharedId))
    XCTAssertFalse(resolver.isActivityInFlight(sharedId))
    XCTAssertFalse(resolver.isNoteInFlight(sharedId))
  }

  func test_emptySetOperations() {
    // Marking empty sets should work without error
    resolver.markTasksInFlight([])
    resolver.markActivitiesInFlight([])
    resolver.markNotesInFlight([])

    XCTAssertTrue(resolver.inFlightTaskIds.isEmpty)
    XCTAssertTrue(resolver.inFlightActivityIds.isEmpty)
    XCTAssertTrue(resolver.inFlightNoteIds.isEmpty)

    // Clearing already-empty sets should work without error
    resolver.clearTasksInFlight()
    resolver.clearActivitiesInFlight()
    resolver.clearNotesInFlight()
    resolver.clearAllInFlight()

    XCTAssertTrue(resolver.inFlightTaskIds.isEmpty)
  }

  // MARK: Private

  private var resolver = ConflictResolver()

}
