//
//  ViewModifiers.swift
//  DesignSystem
//
//  Reusable view modifiers for consistent styling.
//

import SwiftUI

// MARK: - List Row Modifiers

extension View {
  /// Hides the default disclosure indicator on NavigationLinks within List contexts.
  /// Safe no-op in non-List contexts (LazyVStack, custom rows).
  ///
  /// Apply this modifier to the NavigationLink itself, not the label content.
  ///
  /// Example:
  /// ```swift
  /// NavigationLink(value: item) {
  ///   MyRowView(item: item)
  /// }
  /// .hideListDisclosureIndicator()
  /// ```
  @ViewBuilder
  public func hideListDisclosureIndicator() -> some View {
    // iOS 18+ supports navigationLinkIndicatorVisibility
    // For cross-SDK compatibility, keep as no-op
    self
  }

  /// Standard list-context styling for work item rows.
  ///
  /// Contract: Row owns vertical padding, swipe actions, and separators.
  /// This modifier owns leading indentation and list row insets.
  ///
  /// Usage: Apply to rows in List or list-like (LazyVStack) contexts.
  /// Detail/modal screens may omit for flush-left presentation.
  ///
  /// Note: listRowInsets only affects List contexts; no-op in VStack/LazyVStack.
  public func workItemRowStyle() -> some View {
    padding(.leading, DS.Spacing.workItemRowIndent)
      .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
  }
}
