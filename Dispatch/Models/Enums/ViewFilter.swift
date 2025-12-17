//
//  ViewFilter.swift
//  Dispatch
//
//  View filter for role-aware filtering in listings
//

import Foundation

/// Filter mode for viewing work items based on audience
enum ViewFilter: CaseIterable {
    case all
    case admin
    case marketing

    /// Returns the next filter in the cycle: All -> Admin -> Marketing -> All
    var next: ViewFilter {
        switch self {
        case .all: return .admin
        case .admin: return .marketing
        case .marketing: return .all
        }
    }

    /// Checks if a work item with the given audiences should be visible under this filter
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

    /// Display label for the filter
    var label: String {
        switch self {
        case .all: return "All"
        case .admin: return "Admin"
        case .marketing: return "Marketing"
        }
    }
}
