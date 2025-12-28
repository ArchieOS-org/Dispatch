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

    /// Returns the next lens in the cycle: All → Admin → Marketing → All
    var next: AudienceLens {
        switch self {
        case .all: return .admin
        case .admin: return .marketing
        case .marketing: return .all
        }
    }

    /// Display label for the filter
    var label: String {
        switch self {
        case .all: return "All"
        case .admin: return "Admin"
        case .marketing: return "Marketing"
        }
    }

    /// SF Symbol icon for the filter button
    var icon: String {
        switch self {
        case .all: return "line.3.horizontal.decrease.circle"
        case .admin: return "person.badge.shield.checkmark"
        case .marketing: return "megaphone"
        }
    }

    /// Adaptive tint color for lens indicator (uses DS tokens)
    var tintColor: Color {
        switch self {
        case .all:
            return .secondary
        case .admin:
            return DS.Colors.RoleColors.admin
        case .marketing:
            return DS.Colors.RoleColors.marketing
        }
    }

    /// Checks if a work item with the given audiences should be visible under this lens
    /// - Parameter audiences: The set of roles the item is visible to
    /// - Returns: true if the item should be shown
    func matches(audiences: Set<Role>) -> Bool {
        switch self {
        case .all:
            return true
        case .admin:
            // Shows admin-only + both
            return audiences.contains(.admin)
        case .marketing:
            // Shows marketing-only + both
            return audiences.contains(.marketing)
        }
    }
}
