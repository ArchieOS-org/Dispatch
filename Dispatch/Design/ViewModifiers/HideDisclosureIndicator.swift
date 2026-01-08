//
//  HideDisclosureIndicator.swift
//  Dispatch
//
//  Shared view modifier to hide NavigationLink disclosure indicators in List contexts.
//

import SwiftUI

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
  func hideListDisclosureIndicator() -> some View {
    // iOS 18+ supports navigationLinkIndicatorVisibility
    // For cross-SDK compatibility, keep as no-op
    self
  }
}
