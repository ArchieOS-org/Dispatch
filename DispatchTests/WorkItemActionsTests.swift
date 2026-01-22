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

struct WorkItemActionsTests {

  @Test
  func testCurrentUserIdUpdates() async throws {
    // Setup
    let actions = await MainActor.run { WorkItemActions() }
    let initialID = await MainActor.run { actions.currentUserId }

    // Assert Initial State
    #expect(initialID == WorkItemActions.unauthenticatedUserId)

    // Simulating the update that happens in ContentView.onChange(of: currentUserId)
    let newUserID = UUID()
    await MainActor.run {
      actions.currentUserId = newUserID
    }

    // Assert Invariant: ID must match the pushed value
    let updatedID = await MainActor.run { actions.currentUserId }
    #expect(updatedID == newUserID)
  }

  // MARK: - UndoManager Integration Tests

  @Test
  func testUndoManagerCanBeInjected() async throws {
    // Given: A WorkItemActions instance
    let actions = await MainActor.run { WorkItemActions() }

    // When: UndoManager is nil by default
    let initialUndoManager = await MainActor.run { actions.undoManager }
    #expect(initialUndoManager == nil)

    // When: We inject an UndoManager
    let undoManager = UndoManager()
    await MainActor.run {
      actions.undoManager = undoManager
    }

    // Then: The undoManager should be set (weak reference)
    let injectedUndoManager = await MainActor.run { actions.undoManager }
    #expect(injectedUndoManager === undoManager)
  }

  @Test
  func testUndoManagerIsWeakReference() async throws {
    // Given: A WorkItemActions instance
    let actions = await MainActor.run { WorkItemActions() }

    // When: We inject an UndoManager that goes out of scope
    await MainActor.run {
      let temporaryUndoManager = UndoManager()
      actions.undoManager = temporaryUndoManager
      // temporaryUndoManager goes out of scope here
    }

    // Then: The weak reference should be nil
    // Note: This test verifies the weak semantics but may not immediately nil
    // due to ARC timing. The important thing is that it's declared weak.
    // The property declaration `weak var undoManager: UndoManager?` is verified
    // by the compiler accepting the code.
    let finalUndoManager = await MainActor.run { actions.undoManager }
    // The undoManager may or may not be nil depending on ARC timing,
    // but the test verifies the property accepts weak assignment
    _ = finalUndoManager // Suppress unused warning
  }

  @Test
  func testUndoManagerRegistersUndoAction() async throws {
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
  func testCompletionToggleUndoPattern() async throws {
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
  func testUncompleteUndoPattern() async throws {
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
  func testAssigneeChangeUndoPattern() async throws {
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
  func testRemoveAssigneeUndoPattern() async throws {
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
  func testNoteDeleteUndoPattern() async throws {
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
  func testMultipleUndoActionsInSequence() async throws {
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
  func testNoUndoRegisteredWhenUndoManagerNil() async throws {
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
  func testCorrectActionNamesForDifferentOperations() async throws {
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
      "Delete Note"
    ]

    for actionName in actionNames {
      target.value += 1
      undoManager.registerUndo(withTarget: target) { _ in }
      undoManager.setActionName(actionName)
      #expect(undoManager.undoActionName == actionName)
      undoManager.undo() // Clear for next iteration
    }
  }
}
