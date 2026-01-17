//
//  ListRowLink.swift
//  Dispatch
//
//  A NavigationLink wrapper for consistent row navigation.
//  Apple's intended pattern: the row IS the NavigationLink.
//

import SwiftUI

// MARK: - ListRowLink

/// A NavigationLink wrapper for navigation rows.
///
/// Uses NavigationLink as the outer container (Apple's intended pattern).
/// Works reliably in both List and LazyVStack contexts.
///
/// ## Accessibility
/// - Always applies `.isButton` trait for VoiceOver
/// - Optional `accessibilityLabel` overrides child content labeling
/// - Optional `accessibilityHint` provides navigation context
///
/// ## Usage
/// ```swift
/// // Basic usage - child content provides accessibility
/// ListRowLink(value: AppRoute.listing(listing.id)) {
///   MyRowContent(item: item)
/// }
///
/// // With explicit accessibility
/// ListRowLink(
///   value: AppRoute.listing(listing.id),
///   accessibilityLabel: "View listing details",
///   accessibilityHint: "Opens the listing detail screen"
/// ) {
///   MyRowContent(item: item)
/// }
/// ```
struct ListRowLink<Value: Hashable, Content: View>: View {

  // MARK: Lifecycle

  init(
    value: Value,
    accessibilityLabel: String? = nil,
    accessibilityHint: String? = nil,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.value = value
    self.accessibilityLabel = accessibilityLabel
    self.accessibilityHint = accessibilityHint
    self.content = content
  }

  // MARK: Internal

  let value: Value
  let accessibilityLabel: String?
  let accessibilityHint: String?
  @ViewBuilder let content: () -> Content

  var body: some View {
    NavigationLink(value: value) {
      content()
    }
    .buttonStyle(.plain)
    .contentShape(Rectangle())
    .accessibilityAddTraits(.isButton)
    .modifier(OptionalAccessibilityLabel(label: accessibilityLabel))
    .modifier(OptionalAccessibilityHint(hint: accessibilityHint))
  }
}

// MARK: - OptionalAccessibilityLabel

private struct OptionalAccessibilityLabel: ViewModifier {
  let label: String?

  func body(content: Content) -> some View {
    if let label {
      content.accessibilityLabel(label)
    } else {
      content
    }
  }
}

// MARK: - OptionalAccessibilityHint

private struct OptionalAccessibilityHint: ViewModifier {
  let hint: String?

  func body(content: Content) -> some View {
    if let hint {
      content.accessibilityHint(hint)
    } else {
      content
    }
  }
}
