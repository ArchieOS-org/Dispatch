//
//  WorkItemRef.swift
//  Dispatch
//
//  ID-only reference for safe navigation that survives ModelContext resets.
//  Created by Claude on 2025-12-07.
//

import Foundation

// MARK: - WorkItemRef

/// A lightweight, ID-only reference to a TaskItem or Activity.
///
/// Use this type for navigation paths instead of `WorkItem` to avoid crashes
/// when SwiftData's ModelContext is reset during sync operations.
///
/// **Why this exists:**
/// SwiftData models become invalid after `ModelContext.reset()`. If a navigation
/// path holds a `WorkItem` (which wraps a model reference), accessing any property
/// on that model after a reset causes a fatal error. By using only UUIDs for
/// navigation, we decouple the navigation state from model lifecycle.
///
/// **Usage pattern:**
/// 1. Navigation paths use `WorkItemRef` values
/// 2. Detail views receive `WorkItemRef` and resolve the actual model via `@Query`
/// 3. If the model no longer exists, show an error state
enum WorkItemRef: Hashable, Identifiable {
  case task(id: UUID)
  case activity(id: UUID)

  var id: UUID {
    switch self {
    case .task(let id): id
    case .activity(let id): id
    }
  }

  var isTask: Bool {
    if case .task = self { return true }
    return false
  }

  var isActivity: Bool {
    if case .activity = self { return true }
    return false
  }
}

// MARK: - Factory Methods

extension WorkItemRef {
  /// Create a reference from a TaskItem
  static func task(_ task: TaskItem) -> WorkItemRef {
    .task(id: task.id)
  }

  /// Create a reference from an Activity
  static func activity(_ activity: Activity) -> WorkItemRef {
    .activity(id: activity.id)
  }

  /// Create a reference from a WorkItem (uses cached snapshot ID)
  static func from(_ workItem: WorkItem) -> WorkItemRef {
    switch workItem {
    case .task(_, let snapshot):
      .task(id: snapshot.id)
    case .activity(_, let snapshot):
      .activity(id: snapshot.id)
    }
  }
}
