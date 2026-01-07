//
//  AppShellView.swift
//  Dispatch
//
//  Created for Dispatch Layout Unification
//

import SwiftUI

/// The top-level application shell.
/// Owns the Window Chrome Policy and Global Navigation Containers.
struct AppShellView: View {
    var body: some View {
        // Phase 0: Wrapping existing ContentView.
        // In Phase 2/3, we will lift the NavigationSplitView/Stack out of ContentView into here.
        ContentView()
            .applyMacWindowPolicy() // Replaces .configureMacWindow()
            #if os(macOS)
            // Hide toolbar background so column backgrounds extend to top
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
            #endif
    }
}
