//
//  SearchPresentationManager.swift
//  Dispatch
//
//  Manages global search presentation state for iPhone navigation.
//  Created by Claude on 2025-12-18.
//

import SwiftUI
import Combine

/// Manages the presentation state of the global search overlay.
///
/// Injected as an environment object at the iPhone navigation root
/// and consumed by `PullToSearchModifier` to trigger search.
@MainActor
final class SearchPresentationManager: ObservableObject {
    /// Whether the search overlay is currently presented
    @Published var isSearchPresented = false

    /// Current search query text
    @Published var searchText = ""

    /// Presents the search overlay
    func presentSearch() {
        isSearchPresented = true
    }

    /// Dismisses the search overlay and clears text
    func dismissSearch() {
        isSearchPresented = false
        searchText = ""
    }
}
