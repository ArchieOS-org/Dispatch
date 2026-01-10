//
//  SidebarState.swift
//  Dispatch
//
//  Manages sidebar state with persistence for macOS
//  Created for DIS-39: Things 3-style collapsible side menu
//

import Combine
import SwiftUI

#if os(macOS)
/// Manages sidebar visibility and width state with persistence.
/// Uses @AppStorage to remember state across app launches.
@MainActor
final class SidebarState: ObservableObject {

  // MARK: Internal

  /// Whether the sidebar is currently visible
  @AppStorage("sidebarVisible") var isVisible = true

  /// Whether the sidebar is currently being dragged
  @Published var isDragging = false

  /// Current sidebar width as CGFloat
  var width: CGFloat {
    get { CGFloat(storedWidth) }
    set { storedWidth = Double(clampedWidth(newValue)) }
  }

  /// Whether to show sidebar based on drag state
  /// During drag, sidebar always stays in view hierarchy (just shrinks to 0 width)
  /// This prevents view hierarchy changes mid-drag which cause glitches
  var shouldShowSidebar: Bool {
    isDragging || isVisible
  }

  /// Clamps width for final persist (min...max)
  func clampedWidth(_ newWidth: CGFloat) -> CGFloat {
    min(DS.Spacing.sidebarMaxWidth, max(DS.Spacing.sidebarMinWidth, newWidth))
  }

  /// Clamps width during drag (0...max) - no min enforcement to allow smooth drag from collapsed
  func clampedWidthDuringDrag(_ newWidth: CGFloat) -> CGFloat {
    min(DS.Spacing.sidebarMaxWidth, max(0, newWidth))
  }

  /// Toggle sidebar visibility (animation handled at view level)
  func toggle() {
    isVisible.toggle()
  }

  /// Show sidebar (animation handled at view level)
  func show() {
    guard !isVisible else { return }
    isVisible = true
  }

  /// Hide sidebar (animation handled at view level)
  func hide() {
    guard isVisible else { return }
    isVisible = false
  }

  // MARK: Private

  /// Current sidebar width (when visible) - default 240pt
  @AppStorage("sidebarWidth") private var storedWidth: Double = 240

}
#endif

// MARK: - Notifications for keyboard shortcuts

extension Notification.Name {
  /// Posted when the sidebar toggle keyboard shortcut is triggered
  static let toggleSidebar = Notification.Name("toggleSidebar")

  /// Posted when the new item keyboard shortcut is triggered (Cmd+N)
  static let newItem = Notification.Name("newItem")

  /// Posted when the search keyboard shortcut is triggered (Cmd+F)
  static let openSearch = Notification.Name("openSearch")

  /// Posted when filter shortcuts are triggered (Cmd+1/2/3)
  static let filterMine = Notification.Name("filterMine")
  static let filterOthers = Notification.Name("filterOthers")
  static let filterUnclaimed = Notification.Name("filterUnclaimed")

  /// Posted when a search result is selected from the popover
  static let navigateSearchResult = Notification.Name("navigateSearchResult")
}
