//
//  ClaimFilter.swift
//  Dispatch
//
//  Filter enum for segmenting work items by claim state
//  Created by Claude on 2025-12-06.
//

import Foundation

/// Filter options for segmenting work items by claim ownership.
/// Used in TaskListView and ActivityListView segmented controls.
enum ClaimFilter: String, CaseIterable, Identifiable {
  case mine = "My Tasks"
  case others = "Others'"
  case unclaimed = "Unclaimed"

  // MARK: Internal

  var id: String {
    rawValue
  }

  /// Checks if a work item matches this filter
  /// - Parameters:
  ///   - claimedBy: The UUID of the user who claimed the item (nil if unclaimed)
  ///   - currentUserId: The current user's UUID
  /// - Returns: true if the item matches the filter criteria
  func matches(claimedBy: UUID?, currentUserId: UUID) -> Bool {
    switch self {
    case .mine:
      claimedBy == currentUserId
    case .others:
      claimedBy != nil && claimedBy != currentUserId
    case .unclaimed:
      claimedBy == nil
    }
  }

  /// Display name for activities (changes "My Tasks" to "My Activities")
  func displayName(forActivities: Bool) -> String {
    if forActivities, self == .mine {
      return "My Activities"
    }
    return rawValue
  }
}
