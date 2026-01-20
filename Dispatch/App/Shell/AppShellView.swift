//
//  AppShellView.swift
//  Dispatch
//
//  Created for Dispatch Layout Unification
//

import SwiftUI

// MARK: - AppShellView

/// The top-level application shell.
/// Owns the Window Chrome Policy and Global Navigation Containers.
struct AppShellView: View {

  // MARK: Internal

  var body: some View {
    // Phase 0: Wrapping existing ContentView.
    // In Phase 2/3, we will lift the NavigationSplitView/Stack out of ContentView into here.
    ContentView()
      .applyMacWindowPolicy() // Replaces .configureMacWindow()
    #if os(macOS)
      // Keep toolbar visible in full-screen
      // Traffic lights appear on hover via FullScreenTrafficLightCoordinator
      .windowToolbarFullScreenVisibility(.visible)
    #endif
  }

}
