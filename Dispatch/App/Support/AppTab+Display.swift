//
//  AppTab+Display.swift
//  Dispatch
//
//  UI-facing extension for AppTab display properties.
//  Keeps AppRouter focused on navigation state.
//

import SwiftUI

// MARK: - AppTab + Identifiable

extension AppTab: Identifiable {
  var id: String {
    rawValue
  }

  var title: String {
    switch self {
    case .workspace: "My Workspace"
    case .properties: "Properties"
    case .listings: "Listings"
    case .realtors: "Realtors"
    case .settings: "Settings"
    case .search: "Search"
    case .descriptionGenerator: "AI Descriptions"
    }
  }

  var icon: String {
    switch self {
    case .workspace: "briefcase"
    case .properties: DS.Icons.Entity.property
    case .listings: DS.Icons.Entity.listing
    case .realtors: DS.Icons.Entity.realtor
    case .settings: "gearshape"
    case .search: "magnifyingglass"
    case .descriptionGenerator: "sparkles"
    }
  }
}

// MARK: - Visibility Rules (Data-Driven)

extension AppTab {
  /// Main navigation tabs for TabView (excludes settings and search).
  /// Settings is in a separate TabSection; search is an overlay.
  static var mainTabs: [AppTab] {
    [.workspace, .properties, .listings, .realtors]
  }

  /// Tabs shown in macOS sidebar (excludes search only).
  /// Settings is now navigated in-window, not a separate scene.
  static var sidebarTabs: [AppTab] {
    allCases.filter(\.showsInSidebar)
  }

  /// Tabs shown in iPhone menu (all except search).
  static var menuTabs: [AppTab] {
    allCases.filter(\.showsInMenu)
  }

  var showsInSidebar: Bool {
    switch self {
    case .search: false
    default: true
    }
  }

  var showsInMenu: Bool {
    self != .search
  }

}
