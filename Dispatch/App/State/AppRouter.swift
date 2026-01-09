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

  // Tab destinations (for iPhone push navigation from menu)
  // On iPad/Mac these are shown via sidebar selection, but iPhone needs to push them
  case workspace
  case propertiesList
  case listingsList
  case realtorsList
  case settingsRoot
}

// MARK: - AppRouter

/// Source of truth for Application Navigation State.
/// Owned by AppState.
///
/// **Architecture:**
/// - iPad/macOS use per-tab NavigationStacks (`paths` dictionary)
/// - iPhone uses a single NavigationStack (`phonePath`)
/// - Tab selection is split into user (may pop) vs programmatic (never pops)
struct AppRouter {
  var selectedTab = AppTab.workspace

  // MARK: - iPad/macOS Per-Tab Stacks

  /// Per-tab navigation paths (iPad/macOS only - NOT shared)
  /// Each tab maintains its own navigation stack, preserving state when switching tabs.
  var paths: [AppTab: [AppRoute]] = [:]

  /// Stable stack IDs - initialized once, mutated only via reducer.
  /// Used to force NavigationStack rebuild when popping to root.
  var stackIDs: [AppTab: UUID] = {
    var ids: [AppTab: UUID] = [:]
    for tab in AppTab.allCases {
      ids[tab] = UUID()
    }
    return ids
  }()

  // MARK: - iPhone Single Stack

  /// iPhone's single navigation path (phone isn't tabbed, uses MenuPageView → push).
  var phonePath: [AppRoute] = []

  /// iPhone stack ID for forced resets.
  var phoneStackID = UUID()

  // MARK: - iPad/macOS Navigation

  /// Navigate to a route on a specific tab (or current tab if nil).
  mutating func navigate(to route: AppRoute, on tab: AppTab? = nil) {
    let targetTab = tab ?? selectedTab
    paths[targetTab, default: []].append(route)
  }

  /// Pop to root for a specific tab (or current tab if nil).
  mutating func popToRoot(for tab: AppTab? = nil) {
    let targetTab = tab ?? selectedTab
    if !(paths[targetTab]?.isEmpty ?? true) {
      paths[targetTab]?.removeAll()
      stackIDs[targetTab] = UUID()
    }
  }

  /// Force stack ID reset for a tab (triggers NavigationStack rebuild).
  mutating func resetStackID(for tab: AppTab) {
    stackIDs[tab] = UUID()
  }

  /// User tapped tab - pops to root if already selected.
  /// Used when user physically taps a tab in TabView.
  mutating func userSelectTab(_ tab: AppTab) {
    if selectedTab == tab {
      popToRoot(for: tab)
    } else {
      selectedTab = tab
    }
  }

  /// Programmatic tab selection - NEVER pops to root.
  /// Used when navigating via stage cards or deep links.
  mutating func setSelectedTab(_ tab: AppTab) {
    selectedTab = tab
  }

  // MARK: - iPhone Navigation

  /// Navigate to a route on iPhone's single stack.
  mutating func phoneNavigate(to route: AppRoute) {
    phonePath.append(route)
  }

  /// Pop to root on iPhone.
  mutating func phonePopToRoot() {
    if !phonePath.isEmpty {
      phonePath.removeAll()
      phoneStackID = UUID()
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
