//
//  AppRouter.swift
//  Dispatch
//
//  Created for Dispatch Architecture Unification
//

import SwiftUI

// MARK: - AppRouter

/// Source of truth for Application Navigation State.
/// Owned by AppState.
struct AppRouter {
  var pathMain = NavigationPath()
  var selectedTab = AppTab.workspace

  /// Used to signal programmatic pushes even if path doesn't change
  /// (e.g. popping to root by tapping tab again)
  var stackID = UUID()

  mutating func navigate(to destination: Destination) {
    pathMain.append(destination)
  }

  mutating func popToRoot() {
    if pathMain.isEmpty {
      // Already at root
    } else {
      pathMain = NavigationPath()
    }
  }

  mutating func selectTab(_ tab: AppTab) {
    if selectedTab == tab {
      // Double tap - pop to root
      popToRoot()
      // Bump stack ID to force SwiftUI to recognize change if needed
      stackID = UUID()
    } else {
      selectedTab = tab
      // Consider if switching tabs should clear path of previous tab?
      // For now, let's say yes for simplicity, or manage per-tab paths later.
      pathMain = NavigationPath()
    }
  }
}

// MARK: - AppTab

enum AppTab: String, CaseIterable, Equatable {
  case workspace
  case properties
  case listings
  case realtors
  case settings
  case search // If search is a tab? Or just an overlay?
}

// MARK: - Route

/// Explicit navigation routes for type-safe, extensible routing.
/// Prevents navigation stack from becoming a bag of unrelated types.
/// Use for new navigation destinations; existing Destination type remains for backwards compatibility.
enum Route: Hashable, Codable {
  case stagedListings(ListingStage)
  // Future routes go here without breaking existing navigation
}
