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
    }
  }
}

// MARK: - Visibility Rules (Data-Driven)

extension AppTab {
  static var sidebarTabs: [AppTab] {
    allCases.filter(\.showsInSidebar)
  }

  static var menuTabs: [AppTab] {
    allCases.filter(\.showsInMenu)
  }

  var showsInSidebar: Bool {
    switch self {
    case .search, .settings: false
    default: true
    }
  }

  var showsInMenu: Bool {
    self != .search
  }

}
