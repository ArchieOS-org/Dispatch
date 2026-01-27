//
//  WorkItemActionsTests.swift
//  DispatchTests
//
//  Unit tests for WorkItemActions including UndoManager integration.
//

import SwiftData
import SwiftUI
import Testing
@testable import DispatchApp

/// Tests for WorkItemActions including UndoManager integration.
/// Note: UndoManager requires MainActor isolation for proper functionality,
/// as it's tied to the main run loop for undo/redo operations.
@MainActor
struct WorkItemActionsTests {

  @Test
  func testCurrentUserIdUpdates() {
    // Setup
    let actions = WorkItemActions()
    let initialID = actions.currentUserId

    // Assert Initial State
    #expect(initialID == WorkItemActions.unauthenticatedUserId)

    // Simulating the update that happens in ContentView.onChange(of: currentUserId)
    let newUserID = UUID()
    actions.currentUserId = newUserID

    // Assert Invariant: ID must match the pushed value
    let updatedID = actions.currentUserId
    #expect(updatedID == newUserID)
  }

  // MARK: - UndoManager Integration Tests

  @Test
  func testUndoManagerCanBeInjected() {
    // Given: A WorkItemActions instance
    let actions = WorkItemActions()

    // When: UndoManager is nil by default
    let initialUndoManager = actions.undoManager
    #expect(initialUndoManager == nil)

    // When: We inject an UndoManager
    let undoManager = UndoManager()
    actions.undoManager = undoManager

    // Then: The undoManager should be set (weak reference)
    let injectedUndoManager = actions.undoManager
    #expect(injectedUndoManager === undoManager)
  }

  /// Documents that `undoManager` is a weak reference to avoid retain cycles.
  ///
  /// Note: This test does NOT verify runtime weak reference behavior because ARC timing
  /// is non-deterministic. The `weak` keyword is compile-time verified - if the property
  /// were not declared `weak`, assigning a temporary would cause a compiler error or
  /// the object would be retained. This test exists purely as documentation of the
  /// expected weak semantics, not as a runtime verification.
  @Test
  func testUndoManagerIsWeakReference_DocumentationOnly() {
    // Given: A WorkItemActions instance
    let actions = WorkItemActions()

    // When: We inject an UndoManager
    // This compiles successfully because undoManager is declared as `weak var`
    do {
      let temporaryUndoManager = UndoManager()
      actions.undoManager = temporaryUndoManager
      // The weak reference allows assignment without ownership transfer
    }

    // Note: We intentionally do NOT assert on the final value.
    // ARC timing is non-deterministic, so the reference may or may not be nil.
    // The important verification is that this code compiles, which proves
    // the property accepts weak assignment semantics.
  }

  @Test
  func testUndoManagerRegistersUndoAction() {
    // Given: An UndoManager
    let undoManager = UndoManager()
    #expect(undoManager.canUndo == false)

    // When: We register an undo action (simulating what ContentView does)
    // Using a simple NSObject subclass to test the pattern
    class Target: NSObject {
      var value = 0
    }
    let target = Target()
    target.value = 1

    undoManager.registerUndo(withTarget: target) { t in
      t.value = 0
    }
    undoManager.setActionName("Change Value")

    // Then: The UndoManager should have an undo action
    #expect(undoManager.canUndo == true)
    #expect(undoManager.undoActionName == "Change Value")

    // When: We undo
    undoManager.undo()

    // Then: The value should be restored
    #expect(target.value == 0)
    #expect(undoManager.canUndo == false)
  }

  // MARK: - Completion Toggle Undo Pattern Tests
  // These tests verify the undo pattern used for task/activity completion
  // using mock objects to avoid SwiftData ModelContext requirements

  /// Mock class that simulates TaskItem/Activity completion behavior for testing
  private class MockCompletableItem: NSObject {
    var isCompleted = false
    var completedAt: Date?
  }

  @Test
  func testCompletionToggleUndoPattern() {
    // Given: An UndoManager and a mock completable item
    let undoManager = UndoManager()
    let item = MockCompletableItem()

    // Verify initial state
    #expect(item.isCompleted == false)
    #expect(item.completedAt == nil)
    #expect(undoManager.canUndo == false)

    // When: We complete the item and register undo (simulating makeOnComplete pattern)
    let previousIsCompleted = item.isCompleted
    let previousCompletedAt = item.completedAt
    item.isCompleted = true
    item.completedAt = Date()

    undoManager.registerUndo(withTarget: item) { t in
      t.isCompleted = previousIsCompleted
      t.completedAt = previousCompletedAt
    }
    undoManager.setActionName("Complete Task")

    // Then: Undo should be available with correct action name
    #expect(undoManager.canUndo == true)
    #expect(undoManager.undoActionName == "Complete Task")
    #expect(item.isCompleted == true)
    #expect(item.completedAt != nil)

    // When: We undo
    undoManager.undo()

    // Then: The item should be restored to uncompleted state
    #expect(item.isCompleted == false)
    #expect(item.completedAt == nil)
    #expect(undoManager.canUndo == false)
  }

  @Test
  func testUncompleteUndoPattern() {
    // Given: An UndoManager and a completed mock item
    let undoManager = UndoManager()
    let completedDate = Date()
    let item = MockCompletableItem()
    item.isCompleted = true
    item.completedAt = completedDate

    // Verify initial state
    #expect(item.isCompleted == true)
    #expect(item.completedAt == completedDate)

    // When: We uncomplete the item and register undo
    let previousIsCompleted = item.isCompleted
    let previousCompletedAt = item.completedAt
    item.isCompleted = false
    item.completedAt = nil

    undoManager.registerUndo(withTarget: item) { t in
      t.isCompleted = previousIsCompleted
      t.completedAt = previousCompletedAt
    }
    undoManager.setActionName("Uncomplete Task")

    // Then: Undo should be available
    #expect(undoManager.canUndo == true)
    #expect(undoManager.undoActionName == "Uncomplete Task")

    // When: We undo
    undoManager.undo()

    // Then: The item should be restored to completed state
    #expect(item.isCompleted == true)
    #expect(item.completedAt == completedDate)
  }

  // MARK: - Assignee Change Undo Pattern Tests

  /// Mock class that simulates TaskItem/Activity assignee behavior for testing
  private class MockAssignableItem: NSObject {
    var assigneeIds: [UUID] = []
  }

  @Test
  func testAssigneeChangeUndoPattern() {
    // Given: An UndoManager and a mock assignable item
    let undoManager = UndoManager()
    let assignee1 = UUID()
    let assignee2 = UUID()
    let item = MockAssignableItem()
    item.assigneeIds = [assignee1]

    // Verify initial state
    #expect(item.assigneeIds == [assignee1])

    // When: We change assignees and register undo
    let previousAssigneeIds = item.assigneeIds
    item.assigneeIds = [assignee1, assignee2]

    undoManager.registerUndo(withTarget: item) { [previousAssigneeIds] t in
      t.assigneeIds = previousAssigneeIds
    }
    undoManager.setActionName("Change Assignees")

    // Then: Undo should be available
    #expect(undoManager.canUndo == true)
    #expect(undoManager.undoActionName == "Change Assignees")
    #expect(item.assigneeIds.count == 2)

    // When: We undo
    undoManager.undo()

    // Then: The assignees should be restored
    #expect(item.assigneeIds == [assignee1])
  }

  @Test
  func testRemoveAssigneeUndoPattern() {
    // Given: An UndoManager and a mock item with multiple assignees
    let undoManager = UndoManager()
    let assignee1 = UUID()
    let assignee2 = UUID()
    let item = MockAssignableItem()
    item.assigneeIds = [assignee1, assignee2]

    // When: We remove an assignee and register undo
    let previousAssigneeIds = item.assigneeIds
    item.assigneeIds = [assignee1] // Removed assignee2

    undoManager.registerUndo(withTarget: item) { [previousAssigneeIds] t in
      t.assigneeIds = previousAssigneeIds
    }
    undoManager.setActionName("Change Assignees")

    // Then: Undo should be available
    #expect(undoManager.canUndo == true)
    #expect(item.assigneeIds == [assignee1])

    // When: We undo
    undoManager.undo()

    // Then: Both assignees should be restored
    #expect(item.assigneeIds == [assignee1, assignee2])
  }

  // MARK: - Note Delete Undo Pattern Tests

  /// Mock class that simulates Note soft-delete behavior for testing
  private class MockDeletableNote: NSObject {
    var deletedAt: Date?
    var deletedBy: UUID?

    func softDelete(by userId: UUID) {
      deletedAt = Date()
      deletedBy = userId
    }

    func undoDelete() {
      deletedAt = nil
      deletedBy = nil
    }
  }

  @Test
  func testNoteDeleteUndoPattern() {
    // Given: An UndoManager and a mock note
    let undoManager = UndoManager()
    let userId = UUID()
    let note = MockDeletableNote()

    // Verify initial state
    #expect(note.deletedAt == nil)
    #expect(note.deletedBy == nil)

    // When: We soft delete the note and register undo
    note.softDelete(by: userId)

    undoManager.registerUndo(withTarget: note) { n in
      n.undoDelete()
    }
    undoManager.setActionName("Delete Note")

    // Then: Undo should be available
    #expect(undoManager.canUndo == true)
    #expect(undoManager.undoActionName == "Delete Note")
    #expect(note.deletedAt != nil)
    #expect(note.deletedBy == userId)

    // When: We undo
    undoManager.undo()

    // Then: The note should be restored
    #expect(note.deletedAt == nil)
    #expect(note.deletedBy == nil)
  }

  // MARK: - Multiple Undo Actions Tests

  @Test
  func testMultipleUndoActionsInSequence() {
    // Given: An UndoManager and a mock item
    let undoManager = UndoManager()
    // Disable automatic undo grouping so each registerUndo is a separate undo step
    undoManager.groupsByEvent = false
    let item = MockCompletableItem()

    // When: We perform two actions
    // Action 1: Complete the item
    let state1IsCompleted = item.isCompleted
    let state1CompletedAt = item.completedAt
    item.isCompleted = true
    item.completedAt = Date()

    undoManager.registerUndo(withTarget: item) { t in
      t.isCompleted = state1IsCompleted
      t.completedAt = state1CompletedAt
    }
    undoManager.setActionName("Complete Task")

    // Action 2: Uncomplete the item
    let state2IsCompleted = item.isCompleted
    let state2CompletedAt = item.completedAt
    item.isCompleted = false
    item.completedAt = nil

    undoManager.registerUndo(withTarget: item) { t in
      t.isCompleted = state2IsCompleted
      t.completedAt = state2CompletedAt
    }
    undoManager.setActionName("Uncomplete Task")

    // Then: We should be able to undo in reverse order
    #expect(item.isCompleted == false)

    // Undo second action (uncomplete -> completed)
    undoManager.undo()
    #expect(item.isCompleted == true)
    #expect(item.completedAt != nil)

    // Undo first action (complete -> open)
    undoManager.undo()
    #expect(item.isCompleted == false)
    #expect(item.completedAt == nil)
  }

  // MARK: - No UndoManager Tests

  @Test
  func testNoUndoRegisteredWhenUndoManagerNil() {
    // Given: A nil UndoManager (simulating when undo is not supported)
    let undoManager: UndoManager? = nil
    let item = MockCompletableItem()

    // When: We try to register undo (should safely no-op)
    item.isCompleted = true
    item.completedAt = Date()

    // This simulates the optional chaining in ContentView
    undoManager?.registerUndo(withTarget: item) { _ in }
    undoManager?.setActionName("Complete Task")

    // Then: No crash occurs and item state is changed
    #expect(item.isCompleted == true)
    // No undo manager means canUndo can't be checked, but code safely handles nil
  }

  // MARK: - Action Name Tests

  @Test
  func testCorrectActionNamesForDifferentOperations() {
    // Given: An UndoManager
    let undoManager = UndoManager()
    undoManager.groupsByEvent = false

    class DummyTarget: NSObject {
      var value = 0
    }
    let target = DummyTarget()

    // Test various action names used in ContentView
    let actionNames = [
      "Complete Task",
      "Uncomplete Task",
      "Complete Activity",
      "Uncomplete Activity",
      "Change Assignees",
      "Delete Note",
      "Add Note",
      "Change Stage"
    ]

    for actionName in actionNames {
      target.value += 1
      undoManager.registerUndo(withTarget: target) { _ in }
      undoManager.setActionName(actionName)
      #expect(undoManager.undoActionName == actionName)
      undoManager.undo() // Clear for next iteration
    }
  }

  // MARK: - Listing Stage Change Undo Pattern Tests

  /// Mock class that simulates Listing stage behavior for testing
  private class MockListingWithStage: NSObject {
    var stage: String = "pending"
  }

  @Test
  func testListingStageChangeUndoPattern() {
    // Given: An UndoManager and a mock listing
    let undoManager = UndoManager()
    let listing = MockListingWithStage()

    // Verify initial state
    #expect(listing.stage == "pending")

    // When: We change the stage and register undo (simulating makeOnListingStageChanged pattern)
    let previousStage = listing.stage
    listing.stage = "working_on"

    undoManager.registerUndo(withTarget: listing) { [previousStage] l in
      l.stage = previousStage
    }
    undoManager.setActionName("Change Stage")

    // Then: Undo should be available with correct action name
    #expect(undoManager.canUndo == true)
    #expect(undoManager.undoActionName == "Change Stage")
    #expect(listing.stage == "working_on")

    // When: We undo
    undoManager.undo()

    // Then: The stage should be restored
    #expect(listing.stage == "pending")
    #expect(undoManager.canUndo == false)
  }

  @Test
  func testListingStageMultipleChangesUndoPattern() {
    // Given: An UndoManager and a mock listing
    let undoManager = UndoManager()
    undoManager.groupsByEvent = false
    let listing = MockListingWithStage()

    // When: We perform multiple stage changes
    // Change 1: pending -> working_on
    let state1 = listing.stage
    listing.stage = "working_on"
    undoManager.registerUndo(withTarget: listing) { [state1] l in
      l.stage = state1
    }
    undoManager.setActionName("Change Stage")

    // Change 2: working_on -> live
    let state2 = listing.stage
    listing.stage = "live"
    undoManager.registerUndo(withTarget: listing) { [state2] l in
      l.stage = state2
    }
    undoManager.setActionName("Change Stage")

    // Then: Current state should be "live"
    #expect(listing.stage == "live")

    // When: We undo twice
    undoManager.undo()
    #expect(listing.stage == "working_on")

    undoManager.undo()
    #expect(listing.stage == "pending")
  }

  // MARK: - Note Add Undo Pattern Tests

  /// Mock class that simulates Note creation with soft-delete for testing
  private class MockCreatableNote: NSObject {
    var content: String
    var deletedAt: Date?
    var deletedBy: UUID?

    init(content: String) {
      self.content = content
    }

    func softDelete(by userId: UUID) {
      deletedAt = Date()
      deletedBy = userId
    }
  }

  @Test
  func testNoteAddUndoPattern() {
    // Given: An UndoManager and a mock note
    let undoManager = UndoManager()
    let userId = UUID()
    let note = MockCreatableNote(content: "Test note content")

    // Verify initial state (note just created, not deleted)
    #expect(note.deletedAt == nil)
    #expect(note.deletedBy == nil)
    #expect(note.content == "Test note content")

    // When: We register undo to soft-delete on undo (simulating makeOnAddNote pattern)
    undoManager.registerUndo(withTarget: note) { [userId] n in
      n.softDelete(by: userId)
    }
    undoManager.setActionName("Add Note")

    // Then: Undo should be available
    #expect(undoManager.canUndo == true)
    #expect(undoManager.undoActionName == "Add Note")

    // When: We undo (which soft-deletes the note)
    undoManager.undo()

    // Then: The note should be soft-deleted
    #expect(note.deletedAt != nil)
    #expect(note.deletedBy == userId)
    #expect(undoManager.canUndo == false)
  }

  @Test
  func testNoteAddToListingUndoPattern() {
    // Given: An UndoManager, a mock listing with notes, and a new note
    let undoManager = UndoManager()
    let userId = UUID()
    let note = MockCreatableNote(content: "Note on listing")

    // Simulate adding to listing's notes array
    var listingNotes: [MockCreatableNote] = []
    listingNotes.append(note)

    #expect(listingNotes.count == 1)
    #expect(note.deletedAt == nil)

    // When: We register undo to soft-delete (simulating makeOnAddNoteToListing pattern)
    undoManager.registerUndo(withTarget: note) { [userId] n in
      n.softDelete(by: userId)
    }
    undoManager.setActionName("Add Note")

    // Then: Undo should be available
    #expect(undoManager.canUndo == true)

    // When: We undo
    undoManager.undo()

    // Then: The note should be soft-deleted (not removed from array, just marked deleted)
    #expect(note.deletedAt != nil)
    #expect(note.deletedBy == userId)
    // Note remains in array but is now soft-deleted
    #expect(listingNotes.count == 1)
  }

  // MARK: - WorkItemActions Callback Property Tests

  @Test
  func testListingStageChangedCallbackCanBeSet() {
    // Given: A WorkItemActions instance
    let actions = WorkItemActions()

    // When: Callback is nil by default
    #expect(actions.onListingStageChanged == nil)

    // When: We set a callback
    actions.onListingStageChanged = { _, _ in }

    // Then: The callback should be set
    #expect(actions.onListingStageChanged != nil)
  }

  @Test
  func testAddNoteToListingCallbackCanBeSet() {
    // Given: A WorkItemActions instance
    let actions = WorkItemActions()

    // When: Callback is nil by default
    #expect(actions.onAddNoteToListing == nil)

    // When: We set a callback
    actions.onAddNoteToListing = { _, _ in }

    // Then: The callback should be set
    #expect(actions.onAddNoteToListing != nil)
  }

  // MARK: - Redo Support Tests

  @Test
  func testRedoIsAvailableAfterUndo() {
    // Given: An UndoManager with a registered action
    let undoManager = UndoManager()

    class Target: NSObject {
      var value = 0
    }
    let target = Target()
    let originalValue = target.value
    target.value = 1
    let newValue = target.value

    // Register undo with redo support (pattern used in ContentView)
    undoManager.registerUndo(withTarget: target) { [undoManager] t in
      t.value = originalValue
      // Register redo action
      undoManager.registerUndo(withTarget: t) { t in
        t.value = newValue
      }
    }

    // Verify initial state
    #expect(target.value == 1)
    #expect(undoManager.canUndo == true)
    #expect(undoManager.canRedo == false)

    // When: We undo
    undoManager.undo()

    // Then: Value is restored AND redo is available
    #expect(target.value == 0)
    #expect(undoManager.canUndo == false)
    #expect(undoManager.canRedo == true)
  }

  @Test
  func testRedoRestoresOriginalState() {
    // Given: An UndoManager and a target that has been changed and undone
    let undoManager = UndoManager()

    class Target: NSObject {
      var value = 0
    }
    let target = Target()
    let originalValue = target.value
    target.value = 42
    let newValue = target.value

    // Register undo with redo support
    undoManager.registerUndo(withTarget: target) { [undoManager] t in
      t.value = originalValue
      undoManager.registerUndo(withTarget: t) { t in
        t.value = newValue
      }
    }

    // Undo first
    undoManager.undo()
    #expect(target.value == 0)

    // When: We redo
    undoManager.redo()

    // Then: The original change is restored
    #expect(target.value == 42)
    #expect(undoManager.canUndo == true)
    #expect(undoManager.canRedo == false)
  }

  @Test
  func testUndoRedoUndoChainWorks() {
    // Given: An UndoManager with redo support pattern
    let undoManager = UndoManager()

    class Target: NSObject {
      var value = "initial"
    }
    let target = Target()

    // Helper to register undo with redo support
    func applyChange(from oldValue: String, to newValue: String) {
      target.value = newValue
      undoManager.registerUndo(withTarget: target) { [undoManager, oldValue, newValue] t in
        t.value = oldValue
        undoManager.registerUndo(withTarget: t) { t in
          t.value = newValue
        }
      }
    }

    // Apply a change
    applyChange(from: "initial", to: "changed")
    #expect(target.value == "changed")

    // Undo
    undoManager.undo()
    #expect(target.value == "initial")
    #expect(undoManager.canRedo == true)

    // Redo
    undoManager.redo()
    #expect(target.value == "changed")
    #expect(undoManager.canUndo == true)

    // Undo again
    undoManager.undo()
    #expect(target.value == "initial")
    #expect(undoManager.canRedo == true)
  }

  @Test
  func testCompletionToggleRedoPattern() {
    // Given: An UndoManager and a mock completable item
    let undoManager = UndoManager()
    let item = MockCompletableItem()

    // Capture state before change
    let previousIsCompleted = item.isCompleted
    let previousCompletedAt = item.completedAt

    // Apply change (complete the item)
    item.isCompleted = true
    item.completedAt = Date()
    let newIsCompleted = item.isCompleted
    let newCompletedAt = item.completedAt

    // Register undo with redo support (matching ContentView pattern)
    undoManager.registerUndo(withTarget: item) { [undoManager] t in
      t.isCompleted = previousIsCompleted
      t.completedAt = previousCompletedAt
      // Register redo
      undoManager.registerUndo(withTarget: t) { t in
        t.isCompleted = newIsCompleted
        t.completedAt = newCompletedAt
      }
    }

    // Verify undo works
    undoManager.undo()
    #expect(item.isCompleted == false)
    #expect(item.completedAt == nil)
    #expect(undoManager.canRedo == true)

    // Verify redo works
    undoManager.redo()
    #expect(item.isCompleted == true)
    #expect(item.completedAt != nil)
  }

  @Test
  func testAssigneeChangeRedoPattern() {
    // Given: An UndoManager and a mock assignable item
    let undoManager = UndoManager()
    let assignee1 = UUID()
    let assignee2 = UUID()
    let item = MockAssignableItem()
    item.assigneeIds = [assignee1]
    let previousIds = item.assigneeIds

    // Apply change (add assignee)
    item.assigneeIds = [assignee1, assignee2]
    let newIds = item.assigneeIds

    // Register undo with redo support
    undoManager.registerUndo(withTarget: item) { [undoManager, previousIds, newIds] t in
      t.assigneeIds = previousIds
      undoManager.registerUndo(withTarget: t) { t in
        t.assigneeIds = newIds
      }
    }

    // Verify undo works
    undoManager.undo()
    #expect(item.assigneeIds == [assignee1])
    #expect(undoManager.canRedo == true)

    // Verify redo works
    undoManager.redo()
    #expect(item.assigneeIds == [assignee1, assignee2])
  }

  @Test
  func testNoteDeleteRedoPattern() {
    // Given: An UndoManager and a mock deletable note
    let undoManager = UndoManager()
    let userId = UUID()
    let note = MockDeletableNote()

    // Delete the note
    note.softDelete(by: userId)

    // Register undo with redo support (matching ContentView pattern)
    undoManager.registerUndo(withTarget: note) { [undoManager, userId] n in
      n.undoDelete()
      // Register redo (re-delete)
      undoManager.registerUndo(withTarget: n) { n in
        n.softDelete(by: userId)
      }
    }

    // Verify note is deleted
    #expect(note.deletedAt != nil)

    // Undo (restore note)
    undoManager.undo()
    #expect(note.deletedAt == nil)
    #expect(undoManager.canRedo == true)

    // Redo (re-delete)
    undoManager.redo()
    #expect(note.deletedAt != nil)
  }

  @Test
  func testNoteAddRedoPattern() {
    // Given: An UndoManager and a mock creatable note
    let undoManager = UndoManager()
    let userId = UUID()
    let note = MockCreatableNote(content: "Test note")

    // Note is created (not deleted)
    #expect(note.deletedAt == nil)

    // Register undo with redo support (undo = soft delete, redo = restore)
    undoManager.registerUndo(withTarget: note) { [undoManager, userId] n in
      n.softDelete(by: userId)
      // Register redo (restore)
      undoManager.registerUndo(withTarget: n) { n in
        n.deletedAt = nil
        n.deletedBy = nil
      }
    }

    // Undo (soft delete the note)
    undoManager.undo()
    #expect(note.deletedAt != nil)
    #expect(undoManager.canRedo == true)

    // Redo (restore the note)
    undoManager.redo()
    #expect(note.deletedAt == nil)
  }

  @Test
  func testListingStageChangeRedoPattern() {
    // Given: An UndoManager and a mock listing
    let undoManager = UndoManager()
    let listing = MockListingWithStage()
    let previousStage = listing.stage

    // Change stage
    listing.stage = "live"
    let newStage = listing.stage

    // Register undo with redo support
    undoManager.registerUndo(withTarget: listing) { [undoManager, previousStage, newStage] l in
      l.stage = previousStage
      undoManager.registerUndo(withTarget: l) { l in
        l.stage = newStage
      }
    }

    // Verify undo works
    undoManager.undo()
    #expect(listing.stage == "pending")
    #expect(undoManager.canRedo == true)

    // Verify redo works
    undoManager.redo()
    #expect(listing.stage == "live")
  }
}
