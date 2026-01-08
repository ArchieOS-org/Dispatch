//
//  ListRowLink.swift
//  Dispatch
//
//  A NavigationLink wrapper for consistent row navigation.
//  Apple's intended pattern: the row IS the NavigationLink.
//

import SwiftUI

/// A NavigationLink wrapper for navigation rows.
///
/// Uses NavigationLink as the outer container (Apple's intended pattern).
/// Works reliably in both List and LazyVStack contexts.
///
/// ## Usage
/// ```swift
/// ListRowLink(value: AppRoute.listing(listing.id)) {
///   MyRowContent(item: item)
/// }
/// ```
struct ListRowLink<Value: Hashable, Content: View>: View {
  let value: Value
  @ViewBuilder let content: () -> Content

  var body: some View {
    NavigationLink(value: value) {
      content()
    }
    .buttonStyle(.plain)
    .contentShape(Rectangle())
  }
}
