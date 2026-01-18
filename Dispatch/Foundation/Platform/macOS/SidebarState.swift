//
//  SidebarState.swift
//  Dispatch
//
//  NOTE: SidebarState has been superseded by WindowUIState for per-window isolation.
//  This file is retained only for the Notification.Name extensions used by keyboard shortcuts.
//  The SidebarState class itself is deprecated.
//

import SwiftUI

// MARK: - Notifications for keyboard shortcuts

extension Notification.Name {
  /// Posted when the sidebar toggle keyboard shortcut is triggered
  static let toggleSidebar = Notification.Name("toggleSidebar")

  /// Posted when the new item keyboard shortcut is triggered (Cmd+N)
  static let newItem = Notification.Name("newItem")

  /// Posted when the search keyboard shortcut is triggered (Cmd+F)
  static let openSearch = Notification.Name("openSearch")

  /// Posted when filter shortcut is triggered (Cmd+1) - legacy, now navigates to workspace
  static let filterMine = Notification.Name("filterMine")

  /// Posted when a search result is selected from the popover
  static let navigateSearchResult = Notification.Name("navigateSearchResult")
}
