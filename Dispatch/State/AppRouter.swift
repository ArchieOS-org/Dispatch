//
//  AppRouter.swift
//  Dispatch
//
//  Created for Dispatch Architecture Unification
//

import SwiftUI

/// Source of truth for Application Navigation State.
/// Owned by AppState.
struct AppRouter {
    var pathMain = NavigationPath()
    var selectedTab: AppTab = .workspace
    
    // Used to signal programmatic pushes even if path doesn't change
    // (e.g. popping to root by tapping tab again)
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

enum AppTab: String, CaseIterable, Equatable {
    case workspace
    case listings
    case realtors
    case search // If search is a tab? Or just an overlay?
}
