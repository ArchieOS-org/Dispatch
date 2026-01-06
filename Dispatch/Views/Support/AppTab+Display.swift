//
//  AppTab+Display.swift
//  Dispatch
//
//  UI-facing extension for AppTab display properties.
//  Keeps AppRouter focused on navigation state.
//

import SwiftUI

// MARK: - Display Properties (UI Layer)

extension AppTab: Identifiable {
  var id: String { rawValue }

  var title: String {
    switch self {
    case .workspace: return "My Workspace"
    case .properties: return "Properties"
    case .listings: return "Listings"
    case .realtors: return "Realtors"
    case .settings: return "Settings"
    case .search: return "Search"
    }
  }

  var icon: String {
    switch self {
    case .workspace: return "briefcase"
    case .properties: return DS.Icons.Entity.property
    case .listings: return DS.Icons.Entity.listing
    case .realtors: return DS.Icons.Entity.realtor
    case .settings: return "gearshape"
    case .search: return "magnifyingglass"
    }
  }
}

// MARK: - Visibility Rules (Data-Driven)

extension AppTab {
  var showsInSidebar: Bool {
    switch self {
    case .search, .settings: return false
    default: return true
    }
  }

  var showsInMenu: Bool {
    self != .search
  }

  static var sidebarTabs: [AppTab] {
    allCases.filter(\.showsInSidebar)
  }

  static var menuTabs: [AppTab] {
    allCases.filter(\.showsInMenu)
  }
}
