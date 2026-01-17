//
//  AppCommand.swift
//  Dispatch
//
//  Created for Dispatch Architecture Unification
//

import Foundation

// MARK: - AppCommand

/// Typed user intents that drive application behavior.
/// Replaces stringly-typed NotificationCenter posts.
enum AppCommand: Equatable {
  // MARK: - Destination Selection (iPad/macOS)

  /// User tapped a sidebar destination - may pop to root if already selected.
  case userSelectedDestination(SidebarDestination)

  /// Programmatic destination selection - NEVER pops to root.
  /// Use for stage card header taps and deep links.
  case setSelectedDestination(SidebarDestination)

  // MARK: - Tab Selection (legacy wrappers - bridge to destination-based)

  /// User physically tapped a tab - may pop to root if same tab is reselected.
  /// Internally bridges to userSelectedDestination(.tab(tab)).
  case userSelectedTab(AppTab)

  /// Programmatic tab selection - NEVER pops to root.
  /// Internally bridges to setSelectedDestination(.tab(tab)).
  case setSelectedTab(AppTab)

  // MARK: - iPad/macOS Navigation (per-destination stacks)

  /// Navigate to a route on a specific destination.
  case navigateTo(AppRoute, on: SidebarDestination)

  /// Set entire path for a destination (used for binding updates).
  case setPath([AppRoute], for: SidebarDestination)

  /// Pop to root for a specific destination.
  case popToRoot(SidebarDestination)

  // MARK: - iPhone Navigation (single stack)

  /// Navigate to a route on iPhone's single stack.
  case phoneNavigateTo(AppRoute)

  /// Set iPhone's entire path (used for binding updates).
  case setPhonePath([AppRoute])

  /// Pop to root on iPhone.
  case phonePopToRoot

  // MARK: - Legacy Navigation (for backwards compatibility during migration)

  /// @deprecated Use navigateTo(_:on:) or phoneNavigateTo(_:) instead.
  case navigate(AppRoute)

  /// @deprecated Use userSelectedTab(_:) instead.
  case selectTab(AppTab)

  // MARK: - Global Actions

  case newItem
  case openSearch(initialText: String? = nil)
  case toggleSidebar
  case syncNow

  // MARK: - Filtering/View Options

  case filterMine
  case filterOthers
  case filterUnclaimed

  // MARK: - AI Tools

  /// Open the AI listing generator, optionally with a preselected listing
  case openListingGenerator(listing: Listing? = nil)

  // MARK: - Deep Linking

  /// Handle an incoming deep link URL (dispatch://...)
  case deepLink(URL)

  // MARK: - Route Cleanup

  /// Remove a route from all navigation paths (used after entity deletion)
  case removeRoute(AppRoute)

  // MARK: - Debug

  case debugSimulateCrash
}
