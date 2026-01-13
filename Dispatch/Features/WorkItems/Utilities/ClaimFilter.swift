//
//  AssignmentFilter.swift
//  Dispatch
//
//  Filter enum for segmenting work items by assignment state
//  Created by Claude on 2025-12-06.
//

import Foundation

/// Filter options for segmenting work items by assignment.
/// Used in TaskListView and ActivityListView segmented controls.
enum AssignmentFilter: String, CaseIterable, Identifiable {
  case mine = "Assigned to Me"
  case others = "Others'"
  case unassigned = "Unassigned"

  // MARK: Internal

  var id: String {
    rawValue
  }

  /// Checks if a work item matches this filter
  /// - Parameters:
  ///   - assigneeUserIds: The UUIDs of users assigned to this item
  ///   - currentUserId: The current user's UUID
  /// - Returns: true if the item matches the filter criteria
  func matches(assigneeUserIds: [UUID], currentUserId: UUID) -> Bool {
    switch self {
    case .mine:
      assigneeUserIds.contains(currentUserId)
    case .others:
      !assigneeUserIds.isEmpty && !assigneeUserIds.contains(currentUserId)
    case .unassigned:
      assigneeUserIds.isEmpty
    }
  }

  /// Display name for activities (changes "Assigned to Me" to "My Activities")
  func displayName(forActivities: Bool) -> String {
    switch self {
    case .mine:
      forActivities ? "My Activities" : "My Tasks"
    case .others:
      "Others'"
    case .unassigned:
      "Unassigned"
    }
  }
}

// MARK: - Legacy Alias

/// Legacy type alias for backward compatibility during migration
typealias ClaimFilter = AssignmentFilter
