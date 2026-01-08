//
//  AppRouter.swift
//  Dispatch
//
//  Created for Dispatch Architecture Unification
//

import SwiftUI

// MARK: - AppRoute

/// Unified navigation route type for entity navigation.
/// All entity navigation uses IDs, never model references.
/// This prevents crashes when SwiftData's ModelContext is reset.
///
/// **Why ID-based:**
/// SwiftData models become invalid after `ModelContext.reset()`. If a navigation
/// path holds a model reference, accessing any property after a reset causes a
/// fatal error. By using only UUIDs for navigation, we decouple navigation state
/// from model lifecycle.
enum AppRoute: Hashable, Sendable {
  // Entities (ID-based for SwiftData stability)
  case realtor(UUID)
  case listing(UUID)
  case property(UUID)
  case listingType(UUID)

  // Feature routes (absorbed from previous types)
  case workItem(WorkItemRef)
  case settings(SettingsSection)
  case stagedListings(ListingStage)
  // NOTE: No .tab case - tabs use TabView(selection:), not NavigationLink
}

// MARK: - AppRouter

/// Source of truth for Application Navigation State.
/// Owned by AppState.
struct AppRouter {
  /// Use typed array instead of NavigationPath (homogeneous = Array per Apple WWDC22)
  var path: [AppRoute] = []
  var selectedTab = AppTab.workspace

  /// Used to signal programmatic pushes even if path doesn't change
  /// (e.g. popping to root by tapping tab again).
  /// Root `NavigationStack` must be keyed by this ID for reliable reset.
  var stackID = UUID()

  mutating func navigate(to route: AppRoute) {
    path.append(route)
  }

  mutating func popToRoot() {
    if !path.isEmpty {
      path.removeAll()
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
      // Switching tabs clears the path
      path.removeAll()
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
  case search // Search is overlay, not push destination
}
