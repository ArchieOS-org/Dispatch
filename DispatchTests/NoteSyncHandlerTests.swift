//
//  NoteSyncHandlerTests.swift
//  DispatchTests
//
//  Unit tests for NoteSyncHandler entity-specific sync operations.
//  Tests applyRemoteNote logic including in-flight and pending protection.
//

import SwiftData
import XCTest
@testable import DispatchApp

// MARK: - NoteSyncHandlerTests

@MainActor
final class NoteSyncHandlerTests: XCTestCase {

  // MARK: Internal

  override func setUp() {
    super.setUp()

    // Create in-memory SwiftData container for testing
    let schema = Schema([Note.self, TaskItem.self, Activity.self, Listing.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    // swiftlint:disable:next force_try
    container = try! ModelContainer(for: schema, configurations: [config])
    context = ModelContext(container)

    // Create dependencies for test mode
    conflictResolver = ConflictResolver()
    let deps = SyncHandlerDependencies(
      mode: .test,
      conflictResolver: conflictResolver,
      getCurrentUserID: { nil },
      getCurrentUser: { nil },
      fetchCurrentUser: { _ in },
      updateListingConfigReady: { _ in }
    )
    handler = NoteSyncHandler(dependencies: deps)
  }

  override func tearDown() {
    context = nil
    container = nil
    handler = nil
    conflictResolver = nil
    super.tearDown()
  }

  // MARK: - Initialization Tests

  func test_init_setsModeProperly() {
    XCTAssertEqual(handler.dependencies.mode, .test)
  }

  func test_init_setsConflictResolver() {
    XCTAssertNotNil(handler.dependencies.conflictResolver)
  }

  // MARK: - applyRemoteNote Tests

  func test_applyRemoteNote_insertsNewNote() throws {
    // Given: A new note DTO that doesn't exist locally
    let noteId = UUID()
    let dto = makeNoteDTO(id: noteId, content: "Test note content")

    // When: Apply the remote note
    try handler.applyRemoteNote(dto: dto, source: .syncDown, context: context)

    // Then: Note should be inserted
    let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == noteId })
    let notes = try context.fetch(descriptor)
    XCTAssertEqual(notes.count, 1)
    XCTAssertEqual(notes.first?.content, "Test note content")
    XCTAssertEqual(notes.first?.syncState, .synced)
  }

  func test_applyRemoteNote_updatesExistingNote() throws {
    // Given: An existing synced note
    let noteId = UUID()
    let existingNote = makeNote(id: noteId, content: "Old content")
    existingNote.markSynced()
    context.insert(existingNote)
    try context.save()

    // When: Apply remote update with new content
    let dto = makeNoteDTO(id: noteId, content: "Updated content")
    try handler.applyRemoteNote(dto: dto, source: .syncDown, context: context)

    // Then: Note should be updated
    let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == noteId })
    let notes = try context.fetch(descriptor)
    XCTAssertEqual(notes.first?.content, "Updated content")
  }

  func test_applyRemoteNote_skipsInFlightNote() throws {
    // Given: A note that is currently being synced up (in-flight)
    let noteId = UUID()
    let existingNote = makeNote(id: noteId, content: "Local content")
    existingNote.markSynced()
    context.insert(existingNote)
    try context.save()

    // Mark as in-flight
    conflictResolver.markNotesInFlight([noteId])

    // When: Apply remote update while in-flight
    let dto = makeNoteDTO(id: noteId, content: "Remote content")
    try handler.applyRemoteNote(dto: dto, source: .syncDown, context: context)

    // Then: Local content should be preserved (in-flight protection)
    let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == noteId })
    let notes = try context.fetch(descriptor)
    XCTAssertEqual(notes.first?.content, "Local content")

    // Cleanup
    conflictResolver.clearNotesInFlight()
  }

  func test_applyRemoteNote_skipsAndMarksPendingNote() throws {
    // Given: A note with pending local changes
    let noteId = UUID()
    let existingNote = makeNote(id: noteId, content: "Pending local edit")
    existingNote.markPending()
    context.insert(existingNote)
    try context.save()

    // When: Apply remote update while pending
    let dto = makeNoteDTO(id: noteId, content: "Remote content")
    try handler.applyRemoteNote(dto: dto, source: .syncDown, context: context)

    // Then: Local content should be preserved
    let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == noteId })
    let notes = try context.fetch(descriptor)
    XCTAssertEqual(notes.first?.content, "Pending local edit")
    // And: Note should be marked as having remote change
    XCTAssertTrue(notes.first?.hasRemoteChangeWhilePending == true)
  }

  func test_applyRemoteNote_handlesSoftDelete() throws {
    // Given: An existing note
    let noteId = UUID()
    let existingNote = makeNote(id: noteId, content: "Original content")
    existingNote.markSynced()
    context.insert(existingNote)
    try context.save()

    // When: Apply soft delete from remote
    let deleterId = UUID()
    let dto = makeNoteDTO(
      id: noteId,
      content: "Original content",
      deletedAt: Date(),
      deletedBy: deleterId
    )
    try handler.applyRemoteNote(dto: dto, source: .syncDown, context: context)

    // Then: Note should be soft-deleted
    let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == noteId })
    let notes = try context.fetch(descriptor)
    XCTAssertNotNil(notes.first?.deletedAt)
    XCTAssertEqual(notes.first?.deletedBy, deleterId)
    XCTAssertEqual(notes.first?.syncState, .synced)
  }

  func test_applyRemoteNote_resurrectsSoftDeletedNote() throws {
    // Given: A soft-deleted note
    let noteId = UUID()
    let existingNote = makeNote(id: noteId, content: "Original")
    existingNote.deletedAt = Date()
    existingNote.deletedBy = UUID()
    existingNote.markSynced()
    context.insert(existingNote)
    try context.save()

    // When: Apply update with no deletedAt (resurrection)
    let dto = makeNoteDTO(id: noteId, content: "Resurrected content")
    try handler.applyRemoteNote(dto: dto, source: .syncDown, context: context)

    // Then: Note should be resurrected
    let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == noteId })
    let notes = try context.fetch(descriptor)
    XCTAssertNil(notes.first?.deletedAt)
    XCTAssertNil(notes.first?.deletedBy)
    XCTAssertEqual(notes.first?.content, "Resurrected content")
  }

  // MARK: - deleteLocalNote Tests

  func test_deleteLocalNote_deletesExistingNote() throws {
    // Given: An existing note
    let noteId = UUID()
    let existingNote = makeNote(id: noteId, content: "To be deleted")
    context.insert(existingNote)
    try context.save()

    // When: Delete the note
    let deleted = try handler.deleteLocalNote(id: noteId, context: context)

    // Then: Note should be deleted
    XCTAssertTrue(deleted)
    let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == noteId })
    let notes = try context.fetch(descriptor)
    XCTAssertTrue(notes.isEmpty)
  }

  func test_deleteLocalNote_returnsFalseForMissingNote() throws {
    // Given: A non-existent note ID
    let missingId = UUID()

    // When: Try to delete
    let deleted = try handler.deleteLocalNote(id: missingId, context: context)

    // Then: Should return false
    XCTAssertFalse(deleted)
  }

  // MARK: - Empty Data Handling

  func test_applyRemoteNote_fromBroadcastSource() throws {
    // Given: A new note via broadcast
    let noteId = UUID()
    let dto = makeNoteDTO(id: noteId, content: "Broadcast note")

    // When: Apply from broadcast source
    try handler.applyRemoteNote(dto: dto, source: .broadcast, context: context)

    // Then: Note should be inserted (same behavior as syncDown)
    let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == noteId })
    let notes = try context.fetch(descriptor)
    XCTAssertEqual(notes.count, 1)
    XCTAssertEqual(notes.first?.content, "Broadcast note")
  }

  // MARK: Private

  // swiftlint:disable implicitly_unwrapped_optional
  private var container: ModelContainer!
  private var context: ModelContext!
  private var handler: NoteSyncHandler!
  private var conflictResolver: ConflictResolver!

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

  private func makeNoteDTO(
    id: UUID = UUID(),
    content: String = "Test content",
    parentType: String = "task",
    parentId: UUID = UUID(),
    deletedAt: Date? = nil,
    deletedBy: UUID? = nil
  ) -> NoteDTO {
    NoteDTO(
      id: id,
      content: content,
      createdBy: UUID(),
      parentType: parentType,
      parentId: parentId,
      editedAt: nil,
      editedBy: nil,
      createdAt: Date(),
      updatedAt: Date(),
      deletedAt: deletedAt,
      deletedBy: deletedBy
    )
  }
}
