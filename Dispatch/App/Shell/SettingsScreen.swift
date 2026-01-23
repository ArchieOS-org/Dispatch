//
//  SettingsScreen.swift
//  Dispatch
//
//  Wrapper for settings sub-screens that hides global floating buttons.
//  Uses AppOverlayState with task-based lifecycle for proper cleanup.
//

import SwiftUI

// MARK: - SettingsScreen

/// Wrapper for settings sub-screens that automatically hides global floating buttons.
///
/// **Why this exists:**
/// GlobalFloatingButtons must be outside NavigationStack to persist during navigation,
/// but this means environment values set by destination views don't reach it.
/// Instead, we use AppOverlayState (EnvironmentObject) which is accessible from both
/// the overlay and the destination views.
///
/// **Lifecycle:**
/// Uses `.task` modifier which properly cancels when the view is removed,
/// ensuring the cleanup code runs even during navigation transitions.
///
/// **Usage:**
/// ```swift
/// var body: some View {
///   SettingsScreen {
///     StandardScreen(title: "Settings", ...) { ... }
///   }
/// }
/// ```
struct SettingsScreen<Content: View>: View {

  // MARK: Lifecycle

  init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }

  // MARK: Internal

  var body: some View {
    content()
      .environment(\.pullToSearchDisabled, true)
      .task {
        // Hide floating buttons when settings screen appears.
        // Using .task ensures cleanup runs when view is removed (task cancellation).
        overlayState.hide(reason: .settingsScreen)

        // This block runs until the task is cancelled (when view disappears).
        // We use withTaskCancellationHandler to ensure show() is called on cleanup.
        await withTaskCancellationHandler {
          // Keep the task alive until cancelled
          while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3600))
          }
        } onCancel: {
          // Called when task is cancelled (view disappears)
          Task { @MainActor in
            overlayState.show(reason: .settingsScreen)
          }
        }
      }
  }

  // MARK: Private

  @EnvironmentObject private var overlayState: AppOverlayState

  private let content: () -> Content

}
