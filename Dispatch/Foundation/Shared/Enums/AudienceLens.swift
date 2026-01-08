//
//  AudienceLens.swift
//  Dispatch
//
//  Audience filter for role-based viewing (All/Admin/Marketing)
//

import Foundation
import SwiftUI

/// Filter mode for viewing work items based on target audience.
/// Used by the global filter button to cycle through audience filters.
enum AudienceLens: String, CaseIterable {
  case all
  case admin
  case marketing

  // MARK: Internal

  /// Returns the next lens in the cycle: All → Admin → Marketing → All
  var next: AudienceLens {
    switch self {
    case .all: .admin
    case .admin: .marketing
    case .marketing: .all
    }
  }

  /// Display label for the filter
  var label: String {
    switch self {
    case .all: "All"
    case .admin: "Admin"
    case .marketing: "Marketing"
    }
  }

  /// SF Symbol icon for the filter button
  /// SF Symbol icon for the filter button
  var icon: String {
    switch self {
    case .all: DS.Icons.Navigation.filter
    case .admin: DS.Icons.RoleIcons.admin
    case .marketing: DS.Icons.RoleIcons.marketing
    }
  }

  /// Adaptive tint color for lens indicator (uses DS tokens)
  var tintColor: Color {
    switch self {
    case .all:
      .secondary
    case .admin:
      DS.Colors.RoleColors.admin
    case .marketing:
      DS.Colors.RoleColors.marketing
    }
  }

  /// Checks if a work item with the given audiences should be visible under this lens
  /// - Parameter audiences: The set of roles the item is visible to
  /// - Returns: true if the item should be shown
  func matches(audiences: Set<Role>) -> Bool {
    switch self {
    case .all:
      true
    case .admin:
      // Shows admin-only + both
      audiences.contains(.admin)
    case .marketing:
      // Shows marketing-only + both
      audiences.contains(.marketing)
    }
  }
}
