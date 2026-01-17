//
//  WindowUIState.swift
//  Dispatch
//
//  Per-window UI state container for macOS multi-window support.
//  Each window instance gets its own WindowUIState via @State at the scene level.
//

import SwiftUI

#if os(macOS)
/// Per-window UI state container.
///
/// This class holds UI state that should be isolated per-window:
/// - Sidebar visibility and width (not persisted - defaults on each window)
/// - Search/overlay state specific to this window
///
/// Usage:
/// ```swift
/// // In DispatchApp.swift or at WindowGroup content level:
/// @State private var windowUIState = WindowUIState()
///
/// WindowGroup {
///   ContentView()
///     .environment(windowUIState)
/// }
/// ```
///
/// **Important**: Do NOT use @StateObject at the App level - that shares
/// state across all windows. Use @State which creates per-window storage.
@Observable
@MainActor
final class WindowUIState {

  // MARK: - Sidebar State

  /// Whether the sidebar is currently visible in this window
  var sidebarVisible: Bool = true

  /// Current sidebar width (when visible) - defaults to 240pt
  var sidebarWidth: CGFloat = DS.Spacing.sidebarDefaultWidth

  /// Whether the sidebar is currently being dragged
  var isDragging: Bool = false

  // MARK: - Overlay State

  /// Search overlay state for this window only
  var overlayState: OverlayState = .none

  /// Whether to show sidebar based on drag state.
  /// During drag, sidebar always stays in view hierarchy (just shrinks to 0 width).
  /// This prevents view hierarchy changes mid-drag which cause glitches.
  var shouldShowSidebar: Bool {
    isDragging || sidebarVisible
  }

  // MARK: - Sidebar Methods

  /// Clamps width for final persist (min...max)
  func clampedWidth(_ newWidth: CGFloat) -> CGFloat {
    min(DS.Spacing.sidebarMaxWidth, max(DS.Spacing.sidebarMinWidth, newWidth))
  }

  /// Clamps width during drag (0...max) - no min enforcement to allow smooth drag from collapsed
  func clampedWidthDuringDrag(_ newWidth: CGFloat) -> CGFloat {
    min(DS.Spacing.sidebarMaxWidth, max(0, newWidth))
  }

  /// Toggle sidebar visibility (animation handled at view level)
  func toggleSidebar() {
    sidebarVisible.toggle()
  }

  /// Show sidebar (animation handled at view level)
  func showSidebar() {
    guard !sidebarVisible else { return }
    sidebarVisible = true
  }

  /// Hide sidebar (animation handled at view level)
  func hideSidebar() {
    guard sidebarVisible else { return }
    sidebarVisible = false
  }

  // MARK: - Overlay Methods

  /// Open search overlay with optional initial text
  func openSearch(initialText: String? = nil) {
    // Idempotency guard: ignore if already searching
    guard case .none = overlayState else { return }
    overlayState = .search(initialText: initialText)
  }

  /// Close any overlay
  func closeOverlay() {
    overlayState = .none
  }

}

// MARK: - Overlay State Enum

extension WindowUIState {
  /// Overlay state for a single window
  enum OverlayState: Equatable {
    case none
    case search(initialText: String?)
    case settings
  }
}
#endif
