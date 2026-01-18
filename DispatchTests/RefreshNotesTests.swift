//
//  RefreshNotesTests.swift
//  DispatchTests
//
//  Regression tests for the SwiftData predicate fix in refreshNotesForParent.
//  Verifies that enum filtering does not crash when fetching notes.
//
//  Bug context: SwiftData predicates cannot call methods (.rawValue) on enum properties.
//  The fix fetches by parentId only, then filters by parentType in memory.
//

import SwiftData
import XCTest
@testable import DispatchApp

// MARK: - RefreshNotesTests

@MainActor
final class RefreshNotesTests: XCTestCase {

  // MARK: Internal

  override func setUp() {
    super.setUp()

    // Create in-memory SwiftData container for testing
    // Only include PersistentModel types needed for Note testing
    let schema = Schema([Note.self, TaskItem.self, Activity.self, Listing.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    // swiftlint:disable:next force_try
    container = try! ModelContainer(for: schema, configurations: [config])
    context = container.mainContext

    // Create SyncManager in test mode
    syncManager = SyncManager(mode: .test)
    syncManager.configure(with: container)
  }

  override func tearDown() {
    context = nil
    container = nil
    syncManager = nil
    super.tearDown()
  }

  // MARK: - Regression Tests for ParentType Enum Filtering

  /// Tests that fetching notes with ParentType.listing does not crash.
  /// This is a regression test for the SwiftData predicate fix.
  func test_fetchNotesForParent_listing_noCrash() throws {
    // Given: Notes with different parent types
    let listingParentId = UUID()
    let taskParentId = UUID()

    let listingNote = makeNote(parentType: .listing, parentId: listingParentId)
    let taskNote = makeNote(parentType: .task, parentId: taskParentId)

    context.insert(listingNote)
    context.insert(taskNote)
    try context.save()

    // When: Fetch using the fixed predicate pattern (parentId only, then filter)
    let descriptor = FetchDescriptor<Note>(predicate: #Predicate {
      $0.parentId == listingParentId
    })
    let allNotesForParent = try context.fetch(descriptor)
    let filteredNotes = allNotesForParent.filter { $0.parentType == .listing }

    // Then: Should not crash and should return correct results
    XCTAssertEqual(filteredNotes.count, 1)
    XCTAssertEqual(filteredNotes.first?.parentType, .listing)
  }

  /// Tests that fetching notes with ParentType.task does not crash.
  func test_fetchNotesForParent_task_noCrash() throws {
    // Given: Notes with different parent types
    let taskParentId = UUID()
    let activityParentId = UUID()

    let taskNote = makeNote(parentType: .task, parentId: taskParentId)
    let activityNote = makeNote(parentType: .activity, parentId: activityParentId)

    context.insert(taskNote)
    context.insert(activityNote)
    try context.save()

    // When: Fetch using the fixed predicate pattern
    let descriptor = FetchDescriptor<Note>(predicate: #Predicate {
      $0.parentId == taskParentId
    })
    let allNotesForParent = try context.fetch(descriptor)
    let filteredNotes = allNotesForParent.filter { $0.parentType == .task }

    // Then: Should not crash and should return correct results
    XCTAssertEqual(filteredNotes.count, 1)
    XCTAssertEqual(filteredNotes.first?.parentType, .task)
  }

  /// Tests that fetching notes with ParentType.activity does not crash.
  func test_fetchNotesForParent_activity_noCrash() throws {
    // Given: Notes with different parent types
    let activityParentId = UUID()
    let listingParentId = UUID()

    let activityNote = makeNote(parentType: .activity, parentId: activityParentId)
    let listingNote = makeNote(parentType: .listing, parentId: listingParentId)

    context.insert(activityNote)
    context.insert(listingNote)
    try context.save()

    // When: Fetch using the fixed predicate pattern
    let descriptor = FetchDescriptor<Note>(predicate: #Predicate {
      $0.parentId == activityParentId
    })
    let allNotesForParent = try context.fetch(descriptor)
    let filteredNotes = allNotesForParent.filter { $0.parentType == .activity }

    // Then: Should not crash and should return correct results
    XCTAssertEqual(filteredNotes.count, 1)
    XCTAssertEqual(filteredNotes.first?.parentType, .activity)
  }

  /// Tests filtering when multiple notes exist for the same parentId but different parentTypes.
  /// This verifies the in-memory filter correctly discriminates by enum value.
  func test_fetchNotesForParent_multipleTypesForSameParent_filtersCorrectly() throws {
    // Given: Same parentId but different parentTypes (edge case)
    // In practice, a parentId would only have one parentType, but this tests the filter logic
    let sharedParentId = UUID()

    let taskNote = makeNote(content: "Task note", parentType: .task, parentId: sharedParentId)
    let activityNote = makeNote(content: "Activity note", parentType: .activity, parentId: sharedParentId)
    let listingNote = makeNote(content: "Listing note", parentType: .listing, parentId: sharedParentId)

    context.insert(taskNote)
    context.insert(activityNote)
    context.insert(listingNote)
    try context.save()

    // When: Fetch all notes for parentId, then filter by each type
    let descriptor = FetchDescriptor<Note>(predicate: #Predicate {
      $0.parentId == sharedParentId
    })
    let allNotesForParent = try context.fetch(descriptor)

    let taskNotes = allNotesForParent.filter { $0.parentType == .task }
    let activityNotes = allNotesForParent.filter { $0.parentType == .activity }
    let listingNotes = allNotesForParent.filter { $0.parentType == .listing }

    // Then: Each filter should return exactly one note
    XCTAssertEqual(allNotesForParent.count, 3)
    XCTAssertEqual(taskNotes.count, 1)
    XCTAssertEqual(activityNotes.count, 1)
    XCTAssertEqual(listingNotes.count, 1)

    XCTAssertEqual(taskNotes.first?.content, "Task note")
    XCTAssertEqual(activityNotes.first?.content, "Activity note")
    XCTAssertEqual(listingNotes.first?.content, "Listing note")
  }

  /// Tests that refreshNotesForParent method can be called without crashing.
  /// Note: In test mode, the network call will fail, but the method should handle errors gracefully.
  func test_refreshNotesForParent_allTypes_completesWithoutCrash() async {
    // Given: SyncManager configured with container
    let listingId = UUID()
    let taskId = UUID()
    let activityId = UUID()

    // When: Call refreshNotesForParent for each ParentType
    // Note: These will fail at the network layer (Supabase call) in test mode,
    // but the method should catch the error and not crash.
    await syncManager.refreshNotesForParent(parentId: listingId, parentType: .listing)
    await syncManager.refreshNotesForParent(parentId: taskId, parentType: .task)
    await syncManager.refreshNotesForParent(parentId: activityId, parentType: .activity)

    // Then: No crash occurred (implicit assertion - test completes)
    // The network errors are caught internally by refreshNotesForParent
  }

  // MARK: Private

  // swiftlint:disable implicitly_unwrapped_optional
  private var container: ModelContainer!
  private var context: ModelContext!
  private var syncManager: SyncManager!
  // swiftlint:enable implicitly_unwrapped_optional

  // MARK: - Test Helpers

  private func makeNote(
    id: UUID = UUID(),
    content: String = "Test content",
    parentType: ParentType = .task,
    parentId: UUID = UUID()
  ) -> Note {
    Note(
      id: id,
      content: content,
      createdBy: UUID(),
      parentType: parentType,
      parentId: parentId
    )
  }
}
