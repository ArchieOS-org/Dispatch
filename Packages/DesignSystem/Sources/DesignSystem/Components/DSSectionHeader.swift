//
//  DSSectionHeader.swift
//  DesignSystem
//
//  Standard non-sticky section header for grouped lists.
//  Includes proper accessibility traits for VoiceOver navigation.
//

import SwiftUI

/// Standard non-sticky section header for grouped lists.
/// Includes proper accessibility traits for VoiceOver navigation.
///
/// Usage:
/// ```swift
/// DSSectionHeader("Properties")
/// DSSectionHeader("Items") { Text("5").foregroundStyle(.secondary) }
/// ```
public struct DSSectionHeader<Trailing: View>: View {

  // MARK: Lifecycle

  /// Creates a section header without trailing content.
  /// - Parameters:
  ///   - title: The header title text.
  ///   - textCase: Optional text case transformation.
  public init(_ title: String, textCase: Text.Case? = nil) where Trailing == EmptyView {
    self.title = title
    self.textCase = textCase
    trailing = EmptyView()
  }

  /// Creates a section header with trailing content.
  /// - Parameters:
  ///   - title: The header title text.
  ///   - textCase: Optional text case transformation.
  ///   - trailing: Trailing content (count badge, chevron, etc.).
  public init(_ title: String, textCase: Text.Case? = nil, @ViewBuilder trailing: () -> Trailing) {
    self.title = title
    self.textCase = textCase
    self.trailing = trailing()
  }

  // MARK: Public

  public var body: some View {
    HStack {
      Text(title)
        .font(DS.Typography.headline)
        .foregroundStyle(DS.Colors.Text.primary)
        .textCase(textCase)

      Spacer()

      trailing
    }
    .padding(.vertical, DS.Spacing.sm)
    .accessibilityAddTraits(.isHeader)
    .accessibilityElement(children: .combine)
  }

  // MARK: Internal

  let title: String
  let textCase: Text.Case?
  let trailing: Trailing

}

// MARK: - Preview

#Preview("DSSectionHeader - Basic") {
  VStack(alignment: .leading, spacing: DS.Spacing.lg) {
    DSSectionHeader("Properties")
    DSSectionHeader("Listings")
    DSSectionHeader("Items")
  }
  .padding()
}

#Preview("DSSectionHeader - With Trailing") {
  VStack(alignment: .leading, spacing: DS.Spacing.lg) {
    DSSectionHeader("Properties") {
      Text("5")
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.tertiary)
    }
    DSSectionHeader("Listings") {
      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundStyle(DS.Colors.Text.tertiary)
    }
    DSSectionHeader("Tasks") {
      HStack(spacing: DS.Spacing.xs) {
        Text("12")
          .font(DS.Typography.caption)
        Image(systemName: "chevron.right")
          .font(.caption)
      }
      .foregroundStyle(DS.Colors.Text.tertiary)
    }
  }
  .padding()
}

#Preview("DSSectionHeader - Text Cases") {
  VStack(alignment: .leading, spacing: DS.Spacing.lg) {
    DSSectionHeader("default case")
    DSSectionHeader("uppercase", textCase: .uppercase)
    DSSectionHeader("lowercase", textCase: .lowercase)
  }
  .padding()
}
