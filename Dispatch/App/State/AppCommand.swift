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
  // MARK: - Tab Selection (split for correctness)

  /// User physically tapped a tab - may pop to root if same tab is reselected.
  case userSelectedTab(AppTab)

  /// Programmatic tab selection - NEVER pops to root.
  /// Use for stage card taps and deep links.
  case setSelectedTab(AppTab)

  // MARK: - iPad/macOS Navigation (per-tab stacks)

  /// Navigate to a route on a specific tab.
  case navigateTo(AppRoute, on: AppTab)

  /// Set entire path for a tab (used for binding updates).
  case setPath([AppRoute], for: AppTab)

  /// Pop to root for a specific tab.
  case popToRoot(AppTab)

  /// Force stack ID reset (triggers NavigationStack rebuild).
  case resetStackID(AppTab)

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

  // MARK: - Debug

  case debugSimulateCrash
}
