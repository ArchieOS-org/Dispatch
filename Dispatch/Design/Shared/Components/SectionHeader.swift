//
//  SectionHeader.swift
//  Dispatch
//
//  Standard non-sticky section header for grouped lists.
//

import SwiftUI

// MARK: - SectionHeader

/// Standard non-sticky section header for grouped lists.
///
/// Use with `StandardGroupedList` for consistent section headers across the app.
/// Includes proper accessibility traits for VoiceOver navigation.
///
/// ## Usage
/// ```swift
/// SectionHeader("Owner Name")
/// SectionHeader("Properties") { Badge(count: 5) }
/// ```
struct SectionHeader<Trailing: View>: View {

  // MARK: Lifecycle

  /// Creates a section header without trailing content.
  init(_ title: String, textCase: Text.Case? = nil) where Trailing == EmptyView {
    self.title = title
    self.textCase = textCase
    trailing = EmptyView()
  }

  /// Creates a section header with trailing content.
  init(_ title: String, textCase: Text.Case? = nil, @ViewBuilder trailing: () -> Trailing) {
    self.title = title
    self.textCase = textCase
    self.trailing = trailing()
  }

  // MARK: Internal

  let title: String
  let textCase: Text.Case?
  let trailing: Trailing

  var body: some View {
    HStack {
      Text(title)
        .font(DS.Typography.headline)
        .foregroundStyle(DS.Colors.Text.secondary)
        .textCase(textCase)

      Spacer()

      trailing
    }
    .padding(.vertical, DS.Spacing.sm)
    .accessibilityAddTraits(.isHeader)
    .accessibilityElement(children: .combine)
  }
}

// MARK: - Preview

#Preview("Section Header - Basic") {
  VStack(alignment: .leading, spacing: DS.Spacing.lg) {
    SectionHeader("Properties")
    SectionHeader("Listings")
    SectionHeader("Staged Items")
  }
  .padding()
}

#Preview("Section Header - With Trailing") {
  VStack(alignment: .leading, spacing: DS.Spacing.lg) {
    SectionHeader("Properties") {
      Text("5")
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.tertiary)
    }
    SectionHeader("Listings") {
      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundStyle(DS.Colors.Text.tertiary)
    }
  }
  .padding()
}
