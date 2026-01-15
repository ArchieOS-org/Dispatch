//
//  WorkItemResolverView.swift
//  Dispatch
//
//  Resolves a WorkItemRef to its underlying model and renders the detail view.
//  Created by Claude on 2025-12-07.
//

import SwiftData
import SwiftUI

// MARK: - WorkItemResolverView

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
  let userLookup: [UUID: User]
  let availableUsers: [User]

  // Actions passed through to detail view
  var onComplete: (WorkItem) -> Void = { _ in }
  var onAssigneesChanged: ((WorkItem, [UUID]) -> Void)?
  var onEditNote: ((Note) -> Void)?
  var onDeleteNote: ((Note, WorkItem) -> Void)?
  var onAddNote: ((String, WorkItem) -> Void)?

  var body: some View {
    switch ref {
    case .task(let id):
      TaskResolverView(
        taskId: id,
        currentUserId: currentUserId,
        userLookup: userLookup,
        availableUsers: availableUsers,
        onComplete: onComplete,
        onAssigneesChanged: onAssigneesChanged,
        onEditNote: onEditNote,
        onDeleteNote: onDeleteNote,
        onAddNote: onAddNote
      )

    case .activity(let id):
      ActivityResolverView(
        activityId: id,
        currentUserId: currentUserId,
        userLookup: userLookup,
        availableUsers: availableUsers,
        onComplete: onComplete,
        onAssigneesChanged: onAssigneesChanged,
        onEditNote: onEditNote,
        onDeleteNote: onDeleteNote,
        onAddNote: onAddNote
      )
    }
  }
}

// MARK: - TaskResolverView

/// Internal view that resolves a task ID to a TaskItem using @Query
private struct TaskResolverView: View {

  // MARK: Lifecycle

  init(
    taskId: UUID,
    currentUserId: UUID,
    userLookup: [UUID: User],
    availableUsers: [User],
    onComplete: @escaping (WorkItem) -> Void,
    onAssigneesChanged: ((WorkItem, [UUID]) -> Void)?,
    onEditNote: ((Note) -> Void)?,
    onDeleteNote: ((Note, WorkItem) -> Void)?,
    onAddNote: ((String, WorkItem) -> Void)?
  ) {
    self.taskId = taskId
    self.currentUserId = currentUserId
    self.userLookup = userLookup
    self.availableUsers = availableUsers
    self.onComplete = onComplete
    self.onAssigneesChanged = onAssigneesChanged
    self.onEditNote = onEditNote
    self.onDeleteNote = onDeleteNote
    self.onAddNote = onAddNote

    // Query for this specific task by ID
    let id = taskId
    _tasks = Query(filter: #Predicate<TaskItem> { $0.id == id })
  }

  // MARK: Internal

  let taskId: UUID
  let currentUserId: UUID
  let userLookup: [UUID: User]
  let availableUsers: [User]

  var onComplete: (WorkItem) -> Void
  var onAssigneesChanged: ((WorkItem, [UUID]) -> Void)?
  var onEditNote: ((Note) -> Void)?
  var onDeleteNote: ((Note, WorkItem) -> Void)?
  var onAddNote: ((String, WorkItem) -> Void)?

  var body: some View {
    if let task = tasks.first {
      let workItem = WorkItem.task(task)
      WorkItemDetailView(
        item: workItem,
        userLookup: userLookup,
        currentUserId: currentUserId,
        availableUsers: availableUsers,
        onComplete: { onComplete(workItem) },
        onAssigneesChanged: { userIds in onAssigneesChanged?(workItem, userIds) },
        onEditNote: onEditNote,
        onDeleteNote: { note in onDeleteNote?(note, workItem) },
        onAddNote: { content in onAddNote?(content, workItem) }
      )
    } else {
      notFoundView
    }
  }

  // MARK: Private

  @Query private var tasks: [TaskItem]

  private var notFoundView: some View {
    ContentUnavailableView {
      Label("Task Not Found", systemImage: DS.Icons.Entity.task)
    } description: {
      Text("This task may have been deleted or is no longer available.")
    }
  }
}

// MARK: - ActivityResolverView

/// Internal view that resolves an activity ID to an Activity using @Query
private struct ActivityResolverView: View {

  // MARK: Lifecycle

  init(
    activityId: UUID,
    currentUserId: UUID,
    userLookup: [UUID: User],
    availableUsers: [User],
    onComplete: @escaping (WorkItem) -> Void,
    onAssigneesChanged: ((WorkItem, [UUID]) -> Void)?,
    onEditNote: ((Note) -> Void)?,
    onDeleteNote: ((Note, WorkItem) -> Void)?,
    onAddNote: ((String, WorkItem) -> Void)?
  ) {
    self.activityId = activityId
    self.currentUserId = currentUserId
    self.userLookup = userLookup
    self.availableUsers = availableUsers
    self.onComplete = onComplete
    self.onAssigneesChanged = onAssigneesChanged
    self.onEditNote = onEditNote
    self.onDeleteNote = onDeleteNote
    self.onAddNote = onAddNote

    // Query for this specific activity by ID
    let id = activityId
    _activities = Query(filter: #Predicate<Activity> { $0.id == id })
  }

  // MARK: Internal

  let activityId: UUID
  let currentUserId: UUID
  let userLookup: [UUID: User]
  let availableUsers: [User]

  var onComplete: (WorkItem) -> Void
  var onAssigneesChanged: ((WorkItem, [UUID]) -> Void)?
  var onEditNote: ((Note) -> Void)?
  var onDeleteNote: ((Note, WorkItem) -> Void)?
  var onAddNote: ((String, WorkItem) -> Void)?

  var body: some View {
    if let activity = activities.first {
      let workItem = WorkItem.activity(activity)
      WorkItemDetailView(
        item: workItem,
        userLookup: userLookup,
        currentUserId: currentUserId,
        availableUsers: availableUsers,
        onComplete: { onComplete(workItem) },
        onAssigneesChanged: { userIds in onAssigneesChanged?(workItem, userIds) },
        onEditNote: onEditNote,
        onDeleteNote: { note in onDeleteNote?(note, workItem) },
        onAddNote: { content in onAddNote?(content, workItem) }
      )
    } else {
      notFoundView
    }
  }

  // MARK: Private

  @Query private var activities: [Activity]

  private var notFoundView: some View {
    ContentUnavailableView {
      Label("Activity Not Found", systemImage: DS.Icons.Entity.activity)
    } description: {
      Text("This activity may have been deleted or is no longer available.")
    }
  }
}
