//
//  DSPill.swift
//  DesignSystem
//
//  Generic pill component for badges and labels.
//  Domain-agnostic building block for specialized pill variants.
//

import SwiftUI

/// A generic pill component for badges, tags, and labels.
/// Use this as a foundation for domain-specific pills (DatePill, OverduePill, etc.).
///
/// Usage:
/// ```swift
/// DSPill { Text("New") }
/// DSPill(foreground: .white, background: .blue) { Text("Active") }
/// ```
public struct DSPill<Content: View>: View {

  // MARK: Lifecycle

  /// Creates a pill with custom colors and content.
  /// - Parameters:
  ///   - foreground: Text/icon color. Defaults to secondary text.
  ///   - background: Background color. Defaults to subtle tertiary.
  ///   - content: The pill's content (typically Text or HStack with icon + text).
  public init(
    foreground: Color = DS.Colors.Text.secondary,
    background: Color = DS.Colors.Text.tertiary.opacity(0.15),
    @ViewBuilder content: @escaping () -> Content
  ) {
    foregroundColor = foreground
    backgroundColor = background
    self.content = content
  }

  // MARK: Public

  public var body: some View {
    content()
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(foregroundColor)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(backgroundColor)
      .clipShape(RoundedRectangle(cornerRadius: 4))
  }

  // MARK: Internal

  let foregroundColor: Color
  let backgroundColor: Color
  @ViewBuilder let content: () -> Content

}

// MARK: - Preview

#Preview("DSPill - Basic") {
  VStack(spacing: DS.Spacing.md) {
    DSPill { Text("Default") }
    DSPill { Text("With Icon") }
    DSPill(foreground: .white, background: .blue) { Text("Custom Colors") }
    DSPill(foreground: .orange, background: .orange.opacity(0.15)) { Text("Warning") }
    DSPill(foreground: .green, background: .green.opacity(0.15)) { Text("Success") }
  }
  .padding()
}

#Preview("DSPill - With Icons") {
  VStack(spacing: DS.Spacing.md) {
    DSPill {
      HStack(spacing: 4) {
        Image(systemName: "star.fill")
        Text("Featured")
      }
    }
    DSPill(foreground: .red, background: .red.opacity(0.15)) {
      HStack(spacing: 4) {
        Image(systemName: "exclamationmark.triangle.fill")
        Text("Urgent")
      }
    }
  }
  .padding()
}
