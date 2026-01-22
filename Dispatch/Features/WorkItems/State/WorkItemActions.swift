//
//  WorkItemActions.swift
//  Dispatch
//
//  Centralized action callbacks for WorkItem navigation
//  Provides stable identity as @StateObject for environments
//

import Combine
import SwiftUI

/// Centralized container for WorkItem-related callbacks and user state.
/// Injected as EnvironmentObject to provide shared navigation destinations.
///
/// CRITICAL: Must be created as `@StateObject` in ContentView, not computed var.
/// Computed vars recreate the object every render, causing lost state.
final class WorkItemActions: ObservableObject {

  // MARK: Lifecycle

  @MainActor
  init(
    currentUserId: UUID = WorkItemActions.unauthenticatedUserId,
    userLookup: @escaping (UUID) -> User? = { _ in nil },
    userLookupDict: [UUID: User] = [:],
    availableUsers: [User] = []
  ) {
    self.currentUserId = currentUserId
    self.userLookup = userLookup
    self.userLookupDict = userLookupDict
    self.availableUsers = availableUsers
  }

  // MARK: Internal

  /// Stable UUID for unauthenticated state
  nonisolated static let unauthenticatedUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()

  /// Current authenticated user ID
  @MainActor var currentUserId: UUID

  /// Lookup function for resolving User from UUID
  @MainActor var userLookup: (UUID) -> User?

  /// Dictionary-based user lookup for multi-assignee views
  @MainActor var userLookupDict: [UUID: User] = [:]

  /// Available users for assignee picker
  @MainActor var availableUsers: [User] = []

  /// Complete/uncomplete a work item
  @MainActor var onComplete: (WorkItem) -> Void = { _ in }

  /// Update assignees on a work item
  @MainActor var onAssigneesChanged: (WorkItem, [UUID]) -> Void = { _, _ in }

  /// Delete a note from a work item (triggers confirmation alert)
  @MainActor var onDeleteNote: (Note, WorkItem) -> Void = { _, _ in }

  /// Add a note to a work item
  @MainActor var onAddNote: (String, WorkItem) -> Void = { _, _ in }

  /// Claim a work item by adding current user to assignees
  @MainActor var onClaim: (WorkItem) -> Void = { _ in }

  /// UndoManager for registering undo actions (injected from SwiftUI Environment)
  @MainActor weak var undoManager: UndoManager?

}
