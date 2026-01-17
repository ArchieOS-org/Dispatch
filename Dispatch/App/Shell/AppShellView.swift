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
      // Hide toolbar background so column backgrounds extend to top
      .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
      // Keep toolbar visible in full-screen (we make the background transparent via NSVisualEffectView)
      // Traffic lights appear on hover via FullScreenTrafficLightCoordinator
      .windowToolbarFullScreenVisibility(.visible)
      .toolbar {
        ToolbarItem(placement: .automatic) {
          DuplicateWindowButton(
            openWindow: openWindow,
            supportsMultipleWindows: supportsMultipleWindows
          )
        }
      }
    #endif
  }

  // MARK: Private

  #if os(macOS)
  @Environment(\.openWindow) private var openWindow
  @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
  #endif

}

#if os(macOS)
// MARK: - Duplicate Window Button

/// Button to create a new window with its own independent state.
/// Minimal icon, positioned on the right side of the toolbar.
private struct DuplicateWindowButton: View {
  let openWindow: OpenWindowAction
  let supportsMultipleWindows: Bool

  var body: some View {
    Button {
      openWindow(id: "main")
    } label: {
      Label("New Window", systemImage: "square.on.square")
    }
    .buttonStyle(.borderless)
    .keyboardShortcut("n", modifiers: [.command, .shift])
    .help("Opens a new window with independent sidebar and search state")
    .disabled(!supportsMultipleWindows)
  }
}
#endif
