//
//  WorkItemResolverView.swift
//  Dispatch
//
//  Resolves a WorkItemRef to its underlying model and renders the detail view.
//  Created by Claude on 2025-12-07.
//

import SwiftUI
import SwiftData

/// A view that resolves a `WorkItemRef` to its underlying SwiftData model
/// and renders the appropriate detail view.
///
/// This view uses `@Query` to fetch fresh model data, ensuring we always
/// have a valid model instance even after `ModelContext.reset()` operations.
///
/// If the model no longer exists (was deleted), an error state is shown.
struct WorkItemResolverView: View {
    let ref: WorkItemRef
    let currentUserId: UUID
    let userLookup: (UUID) -> User?

    // Actions passed through to detail view
    var onComplete: (WorkItem) -> Void = { _ in }
    var onClaim: (WorkItem) -> Void = { _ in }
    var onRelease: (WorkItem) -> Void = { _ in }
    var onEditNote: ((Note) -> Void)?
    var onDeleteNote: ((Note, WorkItem) -> Void)?
    var onAddNote: ((String, WorkItem) -> Void)?
    var onToggleSubtask: ((Subtask) -> Void)?
    var onDeleteSubtask: ((Subtask, WorkItem) -> Void)?
    var onAddSubtask: ((WorkItem) -> Void)?

    var body: some View {
        switch ref {
        case .task(let id):
            TaskResolverView(
                taskId: id,
                currentUserId: currentUserId,
                userLookup: userLookup,
                onComplete: onComplete,
                onClaim: onClaim,
                onRelease: onRelease,
                onEditNote: onEditNote,
                onDeleteNote: onDeleteNote,
                onAddNote: onAddNote,
                onToggleSubtask: onToggleSubtask,
                onDeleteSubtask: onDeleteSubtask,
                onAddSubtask: onAddSubtask
            )
        case .activity(let id):
            ActivityResolverView(
                activityId: id,
                currentUserId: currentUserId,
                userLookup: userLookup,
                onComplete: onComplete,
                onClaim: onClaim,
                onRelease: onRelease,
                onEditNote: onEditNote,
                onDeleteNote: onDeleteNote,
                onAddNote: onAddNote,
                onToggleSubtask: onToggleSubtask,
                onDeleteSubtask: onDeleteSubtask,
                onAddSubtask: onAddSubtask
            )
        }
    }
}

// MARK: - Task Resolver

/// Internal view that resolves a task ID to a TaskItem using @Query
private struct TaskResolverView: View {
    let taskId: UUID
    let currentUserId: UUID
    let userLookup: (UUID) -> User?

    var onComplete: (WorkItem) -> Void
    var onClaim: (WorkItem) -> Void
    var onRelease: (WorkItem) -> Void
    var onEditNote: ((Note) -> Void)?
    var onDeleteNote: ((Note, WorkItem) -> Void)?
    var onAddNote: ((String, WorkItem) -> Void)?
    var onToggleSubtask: ((Subtask) -> Void)?
    var onDeleteSubtask: ((Subtask, WorkItem) -> Void)?
    var onAddSubtask: ((WorkItem) -> Void)?

    @Query private var tasks: [TaskItem]

    init(
        taskId: UUID,
        currentUserId: UUID,
        userLookup: @escaping (UUID) -> User?,
        onComplete: @escaping (WorkItem) -> Void,
        onClaim: @escaping (WorkItem) -> Void,
        onRelease: @escaping (WorkItem) -> Void,
        onEditNote: ((Note) -> Void)?,
        onDeleteNote: ((Note, WorkItem) -> Void)?,
        onAddNote: ((String, WorkItem) -> Void)?,
        onToggleSubtask: ((Subtask) -> Void)?,
        onDeleteSubtask: ((Subtask, WorkItem) -> Void)?,
        onAddSubtask: ((WorkItem) -> Void)?
    ) {
        self.taskId = taskId
        self.currentUserId = currentUserId
        self.userLookup = userLookup
        self.onComplete = onComplete
        self.onClaim = onClaim
        self.onRelease = onRelease
        self.onEditNote = onEditNote
        self.onDeleteNote = onDeleteNote
        self.onAddNote = onAddNote
        self.onToggleSubtask = onToggleSubtask
        self.onDeleteSubtask = onDeleteSubtask
        self.onAddSubtask = onAddSubtask

        // Query for this specific task by ID
        let id = taskId
        _tasks = Query(filter: #Predicate<TaskItem> { $0.id == id })
    }

    var body: some View {
        if let task = tasks.first {
            let workItem = WorkItem.task(task)
            WorkItemDetailView(
                item: workItem,
                claimState: claimState(for: workItem),
                userLookup: userLookup,
                onComplete: { onComplete(workItem) },
                onClaim: { onClaim(workItem) },
                onRelease: { onRelease(workItem) },
                onEditNote: onEditNote,
                onDeleteNote: { note in onDeleteNote?(note, workItem) },
                onAddNote: { content in onAddNote?(content, workItem) },
                onToggleSubtask: onToggleSubtask,
                onDeleteSubtask: { subtask in onDeleteSubtask?(subtask, workItem) },
                onAddSubtask: { onAddSubtask?(workItem) }
            )
        } else {
            notFoundView
        }
    }

    private func claimState(for item: WorkItem) -> ClaimState {
        guard let claimedById = item.claimedBy else {
            return .unclaimed
        }
        if claimedById == currentUserId {
            if let user = userLookup(claimedById) {
                return .claimedByMe(user: user)
            }
            return .claimedByMe(user: User(name: "You", email: "", userType: .realtor))
        } else {
            if let user = userLookup(claimedById) {
                return .claimedByOther(user: user)
            }
            return .claimedByOther(user: User(name: "Unknown", email: "", userType: .realtor))
        }
    }

    private var notFoundView: some View {
        ContentUnavailableView {
            Label("Task Not Found", systemImage: DS.Icons.Entity.task)
        } description: {
            Text("This task may have been deleted or is no longer available.")
        }
    }
}

// MARK: - Activity Resolver

/// Internal view that resolves an activity ID to an Activity using @Query
private struct ActivityResolverView: View {
    let activityId: UUID
    let currentUserId: UUID
    let userLookup: (UUID) -> User?

    var onComplete: (WorkItem) -> Void
    var onClaim: (WorkItem) -> Void
    var onRelease: (WorkItem) -> Void
    var onEditNote: ((Note) -> Void)?
    var onDeleteNote: ((Note, WorkItem) -> Void)?
    var onAddNote: ((String, WorkItem) -> Void)?
    var onToggleSubtask: ((Subtask) -> Void)?
    var onDeleteSubtask: ((Subtask, WorkItem) -> Void)?
    var onAddSubtask: ((WorkItem) -> Void)?

    @Query private var activities: [Activity]

    init(
        activityId: UUID,
        currentUserId: UUID,
        userLookup: @escaping (UUID) -> User?,
        onComplete: @escaping (WorkItem) -> Void,
        onClaim: @escaping (WorkItem) -> Void,
        onRelease: @escaping (WorkItem) -> Void,
        onEditNote: ((Note) -> Void)?,
        onDeleteNote: ((Note, WorkItem) -> Void)?,
        onAddNote: ((String, WorkItem) -> Void)?,
        onToggleSubtask: ((Subtask) -> Void)?,
        onDeleteSubtask: ((Subtask, WorkItem) -> Void)?,
        onAddSubtask: ((WorkItem) -> Void)?
    ) {
        self.activityId = activityId
        self.currentUserId = currentUserId
        self.userLookup = userLookup
        self.onComplete = onComplete
        self.onClaim = onClaim
        self.onRelease = onRelease
        self.onEditNote = onEditNote
        self.onDeleteNote = onDeleteNote
        self.onAddNote = onAddNote
        self.onToggleSubtask = onToggleSubtask
        self.onDeleteSubtask = onDeleteSubtask
        self.onAddSubtask = onAddSubtask

        // Query for this specific activity by ID
        let id = activityId
        _activities = Query(filter: #Predicate<Activity> { $0.id == id })
    }

    var body: some View {
        if let activity = activities.first {
            let workItem = WorkItem.activity(activity)
            WorkItemDetailView(
                item: workItem,
                claimState: claimState(for: workItem),
                userLookup: userLookup,
                onComplete: { onComplete(workItem) },
                onClaim: { onClaim(workItem) },
                onRelease: { onRelease(workItem) },
                onEditNote: onEditNote,
                onDeleteNote: { note in onDeleteNote?(note, workItem) },
                onAddNote: { content in onAddNote?(content, workItem) },
                onToggleSubtask: onToggleSubtask,
                onDeleteSubtask: { subtask in onDeleteSubtask?(subtask, workItem) },
                onAddSubtask: { onAddSubtask?(workItem) }
            )
        } else {
            notFoundView
        }
    }

    private func claimState(for item: WorkItem) -> ClaimState {
        guard let claimedById = item.claimedBy else {
            return .unclaimed
        }
        if claimedById == currentUserId {
            if let user = userLookup(claimedById) {
                return .claimedByMe(user: user)
            }
            return .claimedByMe(user: User(name: "You", email: "", userType: .realtor))
        } else {
            if let user = userLookup(claimedById) {
                return .claimedByOther(user: user)
            }
            return .claimedByOther(user: User(name: "Unknown", email: "", userType: .realtor))
        }
    }

    private var notFoundView: some View {
        ContentUnavailableView {
            Label("Activity Not Found", systemImage: DS.Icons.Entity.activity)
        } description: {
            Text("This activity may have been deleted or is no longer available.")
        }
    }
}
