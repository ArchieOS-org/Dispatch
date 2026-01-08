//
//  Listing+Progress.swift
//  Dispatch
//
//  Extension for computing listing progress from tasks and activities.
//  Created by Claude on 2025-12-13.
//

import Foundation

extension Listing {
  /// Active (non-deleted) tasks for this listing
  var activeTasks: [TaskItem] {
    tasks.filter { $0.status != .deleted }
  }

  /// Active (non-deleted) activities for this listing
  var activeActivities: [Activity] {
    activities.filter { $0.status != .deleted }
  }

  /// Number of completed items (tasks + activities with .completed status)
  var completedItemCount: Int {
    activeTasks.count(where: { $0.status == .completed }) +
      activeActivities.count(where: { $0.status == .completed })
  }

  /// Total count of active items (tasks + activities, excluding deleted)
  var totalItemCount: Int {
    activeTasks.count + activeActivities.count
  }

  /// Progress from 0.0 to 1.0 representing completion of tasks and activities.
  /// Returns 0 if there are no active items.
  var progress: Double {
    guard totalItemCount > 0 else { return 0 }
    return Double(completedItemCount) / Double(totalItemCount)
  }
}
