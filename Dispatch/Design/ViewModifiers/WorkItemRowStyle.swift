//
//  WorkItemRowStyle.swift
//  Dispatch
//
//  View modifier for consistent WorkItemRow list-context styling.
//  Created by Claude on 2025-01-08.
//

import SwiftUI

extension View {
  /// Standard list-context styling for WorkItemRow.
  ///
  /// Contract: WorkItemRow owns vertical padding, swipe actions, and separators.
  /// This modifier owns leading indentation and list row insets.
  ///
  /// Usage: Apply to WorkItemRow in List or list-like (LazyVStack) contexts.
  /// Detail/modal screens may omit for flush-left presentation.
  ///
  /// Note: listRowInsets only affects List contexts; no-op in VStack/LazyVStack.
  func workItemRowStyle() -> some View {
    padding(.leading, DS.Spacing.workItemRowIndent)
      .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
  }
}
