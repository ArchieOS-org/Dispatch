//
//  WindowContentView.swift
//  Dispatch
//
//  Wrapper view that owns per-window state.
//  SwiftUI creates new @State storage for each window instance.
//

import SwiftUI

// MARK: - WindowContentView

/// Wrapper view that owns per-window state.
///
/// This view exists specifically to hold `@State` properties that should be
/// isolated per-window on macOS. When placed inside a WindowGroup, SwiftUI
/// allocates new storage for each window that opens.
///
/// **Why not put this in DispatchApp?**
/// Property wrappers like `@State` can't be used directly in the App struct's
/// body - they must be in a View. This wrapper view solves that.
struct WindowContentView: View {

  // MARK: Internal

  // MARK: - Properties

  /// Reference to the shared app state (injected, not per-window)
  let appState: AppState

  // MARK: - Body

  var body: some View {
    Group {
      if DispatchApp.isUITesting || appState.authManager.isAuthenticated {
        if DispatchApp.isUITesting || syncManager.currentUser != nil {
          AppShellView()
        } else {
          OnboardingLoadingView()
        }
      } else {
        LoginView()
      }
    }
    .animation(.easeInOut, value: appState.authManager.isAuthenticated)
    .animation(.easeInOut, value: syncManager.currentUser != nil)
    #if os(macOS)
      // Inject per-window state into environment (macOS only)
      .environment(windowUIState)
    #endif
  }

  // MARK: Private

  /// Observed sync manager for currentUser changes
  @EnvironmentObject private var syncManager: SyncManager

  #if os(macOS)
  /// Per-window UI state - each window gets its own instance
  /// This is the key to multi-window state isolation
  @State private var windowUIState = WindowUIState()
  #endif

}

// MARK: - Previews

#Preview("Authenticated") {
  WindowContentView(appState: AppState(mode: .preview))
    .environmentObject(SyncManager.shared)
}

#Preview("Login View") {
  WindowContentView(appState: AppState(mode: .preview))
    .environmentObject(SyncManager.shared)
}
