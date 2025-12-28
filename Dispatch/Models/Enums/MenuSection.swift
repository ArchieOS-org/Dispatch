//
//  MenuSection.swift
//  Dispatch
//
//  Represents menu sections for iPhone navigation
//

import SwiftUI

/// Menu sections for the iPhone Things 3-style navigation
enum MenuSection: String, CaseIterable, Identifiable, Hashable {
    case tasks
    case activities
    case listings
    case realtors

    var id: String { rawValue }

    /// Display title for the section
    var title: String {
        switch self {
        case .tasks: return "Tasks"
        case .activities: return "Activities"
        case .listings: return "Listings"
        case .realtors: return "Realtors"
        }
    }

    /// SF Symbol icon name from design system
    var icon: String {
        switch self {
        case .tasks: return DS.Icons.Entity.task
        case .activities: return DS.Icons.Entity.activity
        case .listings: return DS.Icons.Entity.listing
        case .realtors: return DS.Icons.Entity.realtor
        }
    }

    /// Accent color for the section
    var accentColor: Color {
        switch self {
        case .tasks: return DS.Colors.info         // Blue
        case .activities: return DS.Colors.warning  // Orange
        case .listings: return DS.Colors.success    // Green
        case .realtors: return .indigo              // Indigo
        }
    }
}
