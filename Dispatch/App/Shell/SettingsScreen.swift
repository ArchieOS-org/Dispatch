//
//  SettingsScreen.swift
//  Dispatch
//
//  Wrapper for settings sub-screens that hides global floating buttons.
//  Uses AppOverlayState (EnvironmentObject) for cross-hierarchy visibility control.
//

import SwiftUI

// MARK: - SettingsScreen

/// Wrapper for settings sub-screens that automatically hides global floating buttons.
///
/// **Why this exists:**
/// GlobalFloatingButtons is rendered as a sibling to NavigationStack (in a ZStack),
/// so environment keys set by pushed views cannot propagate to it.
/// Instead, we use AppOverlayState (an EnvironmentObject shared across the entire app)
/// with onAppear/onDisappear to control visibility.
///
/// **Reference-counted reasons prevent stuck states:**
/// Even if navigation timing causes onDisappear to fire after onAppear of another screen,
/// the `.settingsScreen` reason is added/removed correctly for each SettingsScreen instance.
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
      .onAppear {
        overlayState.hide(reason: .settingsScreen)
      }
      .onDisappear {
        overlayState.show(reason: .settingsScreen)
      }
  }

  // MARK: Private

  @EnvironmentObject private var overlayState: AppOverlayState

  private let content: () -> Content

}
