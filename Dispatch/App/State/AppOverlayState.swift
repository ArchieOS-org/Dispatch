//
//  AppOverlayState.swift
//  Dispatch
//
//  Controls floating buttons visibility via reference-counted reasons
//

import Combine
import SwiftUI

// MARK: - GlobalButtonsHiddenKey

/// Environment key to hide global floating buttons in a view hierarchy.
/// Used by SettingsScreen wrapper to automatically hide buttons for all settings sub-screens.
/// This approach avoids race conditions from onAppear/onDisappear timing issues.
private struct GlobalButtonsHiddenKey: EnvironmentKey {
  static let defaultValue = false
}

// MARK: - EnvironmentValues + GlobalButtonsHidden

extension EnvironmentValues {
  /// When true, global floating buttons are hidden for this view hierarchy.
  /// Set this at a root container (like SettingsScreen) to hide for all descendants.
  var globalButtonsHidden: Bool {
    get { self[GlobalButtonsHiddenKey.self] }
    set { self[GlobalButtonsHiddenKey.self] = newValue }
  }
}

// MARK: - AppOverlayState

/// Controls visibility of floating buttons (filter + FAB) using reference-counted reasons.
/// Prevents stuck states when multiple fields focus/unfocus.
///
/// Usage:
/// ```swift
/// @EnvironmentObject private var overlayState: AppOverlayState
/// @FocusState private var isFocused: Bool
///
/// .focused($isFocused)
/// .onChange(of: isFocused) { _, focused in
///     if focused {
///         overlayState.hide(reason: .textInput)
///     } else {
///         overlayState.show(reason: .textInput)
///     }
/// }
/// ```
@MainActor
final class AppOverlayState: ObservableObject {

  // MARK: Lifecycle

  init(mode: RunMode = .live) {
    self.mode = mode
  }

  // MARK: Internal

  /// Reasons why the overlay should be hidden
  enum HideReason: Hashable {
    case textInput
    case keyboard
    case modal
    case searchOverlay
    case settingsScreen
  }

  enum RunMode {
    case live
    case preview
  }

  let mode: RunMode

  /// Active reasons for hiding the overlay
  @Published private(set) var activeReasons = Set<HideReason>()

  /// Returns true if the overlay should be hidden (any reason is active)
  var isOverlayHidden: Bool {
    !activeReasons.isEmpty
  }

  /// Returns true if the given reason is currently active
  func isReasonActive(_ reason: HideReason) -> Bool {
    activeReasons.contains(reason)
  }

  /// Hides the overlay for the given reason
  func hide(reason: HideReason) {
    activeReasons.insert(reason)
  }

  /// Shows the overlay by removing the given reason
  func show(reason: HideReason) {
    activeReasons.remove(reason)
  }
}
