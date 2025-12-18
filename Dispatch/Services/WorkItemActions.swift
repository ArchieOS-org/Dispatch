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
    // MARK: - User State (updated via onChange/onAppear)

    /// Current authenticated user ID
    @MainActor var currentUserId: UUID

    /// Lookup function for resolving User from UUID
    @MainActor var userLookup: (UUID) -> User?

    // MARK: - Callbacks

    /// Complete/uncomplete a work item
    @MainActor var onComplete: (WorkItem) -> Void = { _ in }

    /// Claim a work item for current user
    @MainActor var onClaim: (WorkItem) -> Void = { _ in }

    /// Release claim on a work item
    @MainActor var onRelease: (WorkItem) -> Void = { _ in }

    /// Delete a note from a work item (triggers confirmation alert)
    @MainActor var onDeleteNote: (Note, WorkItem) -> Void = { _, _ in }

    /// Add a note to a work item
    @MainActor var onAddNote: (String, WorkItem) -> Void = { _, _ in }

    /// Toggle subtask completion
    @MainActor var onToggleSubtask: (Subtask) -> Void = { _ in }

    /// Delete a subtask from a work item (triggers confirmation alert)
    @MainActor var onDeleteSubtask: (Subtask, WorkItem) -> Void = { _, _ in }

    /// Add a subtask to a work item (triggers sheet)
    @MainActor var onAddSubtask: (WorkItem) -> Void = { _ in }

    // MARK: - Sentinel Values

    /// Stable UUID for unauthenticated state
    nonisolated static let unauthenticatedUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    // MARK: - Init

    @MainActor
    init(
        currentUserId: UUID = WorkItemActions.unauthenticatedUserId,
        userLookup: @escaping (UUID) -> User? = { _ in nil }
    ) {
        self.currentUserId = currentUserId
        self.userLookup = userLookup
    }
}
