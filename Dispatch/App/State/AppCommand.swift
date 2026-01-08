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
  // MARK: - Navigation
  case navigate(AppRoute)
  case popToRoot
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
