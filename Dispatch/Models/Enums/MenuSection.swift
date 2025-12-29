//
//  MenuSection.swift
//  Dispatch
//
//  Represents menu sections for iPhone navigation
//

import SwiftUI

/// Menu sections for the iPhone Things 3-style navigation
enum MenuSection: String, CaseIterable, Identifiable, Hashable {
    case myWorkspace
    case listings
    case realtors

    var id: String { rawValue }

    /// Display title for the section
    var title: String {
        switch self {
        case .myWorkspace: return "My Workspace"
        case .listings: return "Listings"
        case .realtors: return "Realtors"
        }
    }

    /// SF Symbol icon name from design system
    var icon: String {
        switch self {
        case .myWorkspace: return "briefcase"
        case .listings: return DS.Icons.Entity.listing
        case .realtors: return DS.Icons.Entity.realtor
        }
    }

    /// Accent color for the section
    var accentColor: Color {
        switch self {
        case .myWorkspace: return DS.Colors.Section.myWorkspace
        case .listings: return DS.Colors.Section.listings
        case .realtors: return DS.Colors.Section.realtors
        }
    }
}
