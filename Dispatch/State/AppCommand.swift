//
//  AppCommand.swift
//  Dispatch
//
//  Created for Dispatch Architecture Unification
//

import Foundation

/// Typed user intents that drive application behavior.
/// Replaces stringly-typed NotificationCenter posts.
enum AppCommand: Equatable {
    // MARK: - Navigation
    case navigate(Destination)
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

/// Destination for navigation commands
enum Destination: Hashable {
    case listing(UUID) // ID of listing
    case workItem(UUID) // ID of work item (Task/Activity)
    case userProfile(UUID)
    // Add others as needed
}
