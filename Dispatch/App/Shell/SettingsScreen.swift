//
//  SettingsScreen.swift
//  Dispatch
//
//  Wrapper for settings sub-screens that hides global floating buttons.
//  Uses environment key to avoid onAppear/onDisappear race conditions
//  during NavigationStack transitions.
//

import SwiftUI

// MARK: - SettingsScreen

/// Wrapper for settings sub-screens that automatically hides global floating buttons.
///
/// **Why this exists:**
/// Using `onAppear`/`onDisappear` to hide/show buttons causes race conditions
/// during navigation because `onDisappear` fires AFTER `onAppear` of the next screen.
/// This wrapper sets an environment key that GlobalFloatingButtons reads directly,
/// avoiding all timing issues.
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
      .environment(\.globalButtonsHidden, true)
      .environment(\.pullToSearchDisabled, true)
  }

  // MARK: Private

  private let content: () -> Content

}
