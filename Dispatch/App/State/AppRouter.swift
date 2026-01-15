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

  /// Feature routes (full-view, not sheet)
  case descriptionGenerator(listingId: UUID?)
}

// MARK: - SidebarDestination

/// Unified selection type for iPad/macOS sidebar.
/// Stages are first-class destinations, not child routes of Listings.
enum SidebarDestination: Hashable {
  case tab(AppTab)
  case stage(ListingStage)

  // MARK: Internal

  /// All possible destinations (tabs + stages) for pre-seeding stackIDs
  static var allDestinations: [SidebarDestination] {
    let tabs = AppTab.allCases.map { SidebarDestination.tab($0) }
    let stages = ListingStage.allCases.map { SidebarDestination.stage($0) }
    return tabs + stages
  }

  /// For backward compatibility with code expecting AppTab
  var asTab: AppTab? {
    if case .tab(let tab) = self { return tab }
    return nil
  }

  /// Check if this destination is a stage
  var isStage: Bool {
    if case .stage = self { return true }
    return false
  }

  /// Get the stage if this is a stage destination
  var asStage: ListingStage? {
    if case .stage(let stage) = self { return stage }
    return nil
  }

}

// MARK: - AppRouter

/// Source of truth for Application Navigation State.
/// Owned by AppState.
///
/// **Architecture:**
/// - iPad/macOS use per-destination NavigationStacks (`paths` dictionary)
/// - iPhone uses a single NavigationStack (`phonePath`)
/// - Destination selection is split into user (may pop) vs programmatic (never pops)
struct AppRouter {
  /// Selected destination for iPad/macOS (tab or stage)
  var selectedDestination: SidebarDestination = .tab(.workspace)

  // MARK: - iPad/macOS Per-Destination Stacks

  /// Per-destination navigation paths (iPad/macOS only - NOT shared)
  /// Each destination maintains its own navigation stack, preserving state when switching.
  var paths: [SidebarDestination: [AppRoute]] = [:]

  /// Stable stack IDs - pre-seeded for all destinations at init.
  /// Used to force NavigationStack rebuild when popping to root.
  /// Pre-seeding ensures stackIDs[destination]! is always safe.
  var stackIDs: [SidebarDestination: UUID] = {
    var ids: [SidebarDestination: UUID] = [:]
    for destination in SidebarDestination.allDestinations {
      ids[destination] = UUID()
    }
    return ids
  }()

  // MARK: - iPhone Single Stack

  /// iPhone's single navigation path (phone isn't tabbed, uses MenuPageView → push).
  var phonePath: [AppRoute] = []

  /// iPhone stack ID for forced resets.
  var phoneStackID = UUID()

  /// Computed property for backward compatibility with tab-based code
  var selectedTab: AppTab {
    selectedDestination.asTab ?? .workspace
  }

  // MARK: - iPad/macOS Navigation (Destination-based)

  /// Navigate to a route on a specific destination (or current destination if nil).
  mutating func navigate(to route: AppRoute, on destination: SidebarDestination? = nil) {
    let target = destination ?? selectedDestination
    paths[target, default: []].append(route)
  }

  /// Pop to root for a specific destination (or current destination if nil).
  mutating func popToRoot(for destination: SidebarDestination? = nil) {
    let target = destination ?? selectedDestination
    if !(paths[target]?.isEmpty ?? true) {
      paths[target]?.removeAll()
      stackIDs[target] = UUID()
    }
  }

  /// Force stack ID reset for a destination (triggers NavigationStack rebuild).
  mutating func resetStackID(for destination: SidebarDestination) {
    stackIDs[destination] = UUID()
  }

  /// User tapped destination - pops to root if already selected.
  /// Used when user physically taps a sidebar item or tab.
  mutating func userSelectDestination(_ destination: SidebarDestination) {
    if selectedDestination == destination {
      popToRoot(for: destination)
    } else {
      selectedDestination = destination
    }
  }

  /// Programmatic destination selection - NEVER pops to root.
  /// Used when navigating via stage cards header or deep links.
  mutating func setSelectedDestination(_ destination: SidebarDestination) {
    selectedDestination = destination
  }

  // MARK: - Legacy Tab Methods (for backward compatibility)

  /// User tapped tab - bridges to destination-based selection.
  mutating func userSelectTab(_ tab: AppTab) {
    userSelectDestination(.tab(tab))
  }

  /// Programmatic tab selection - bridges to destination-based selection.
  mutating func setSelectedTab(_ tab: AppTab) {
    setSelectedDestination(.tab(tab))
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
  case descriptionGenerator // AI listing description tool
}
