//
//  DSDivider.swift
//  DesignSystem
//
//  Styled divider component with configurable appearance.
//  Uses semantic separator color for proper dark mode support.
//

import SwiftUI

/// A styled divider with configurable thickness and color.
/// Uses semantic colors for proper dark mode adaptation.
///
/// Usage:
/// ```swift
/// DSDivider()                           // Default 1pt separator
/// DSDivider(thickness: 2)               // Thicker divider
/// DSDivider(color: DS.Colors.accent)    // Colored divider
/// ```
public struct DSDivider: View {

  // MARK: - Orientation

  /// Divider orientation
  public enum Orientation {
    case horizontal
    case vertical
  }

  // MARK: Lifecycle

  /// Creates a divider with the specified appearance.
  /// - Parameters:
  ///   - orientation: Horizontal or vertical. Defaults to horizontal.
  ///   - thickness: Line thickness in points. Defaults to 1pt.
  ///   - color: Divider color. Defaults to system separator.
  ///   - inset: Leading/trailing inset for horizontal, top/bottom for vertical.
  public init(
    orientation: Orientation = .horizontal,
    thickness: CGFloat = 1,
    color: Color = DS.Colors.separator,
    inset: CGFloat = 0
  ) {
    self.orientation = orientation
    self.thickness = thickness
    self.color = color
    self.inset = inset
  }

  // MARK: Public

  public var body: some View {
    switch orientation {
    case .horizontal:
      Rectangle()
        .fill(color)
        .frame(height: thickness)
        .padding(.horizontal, inset)
    case .vertical:
      Rectangle()
        .fill(color)
        .frame(width: thickness)
        .padding(.vertical, inset)
    }
  }

  // MARK: Internal

  let orientation: Orientation
  let thickness: CGFloat
  let color: Color
  let inset: CGFloat

}

// MARK: - Preview

#Preview("DSDivider - Horizontal") {
  VStack(spacing: DS.Spacing.lg) {
    Text("Item 1")
    DSDivider()
    Text("Item 2")
    DSDivider(thickness: 2)
    Text("Item 3")
    DSDivider(color: DS.Colors.accent)
    Text("Item 4")
    DSDivider(inset: DS.Spacing.lg)
    Text("Item 5 (inset divider above)")
  }
  .padding()
}

#Preview("DSDivider - Vertical") {
  HStack(spacing: DS.Spacing.lg) {
    Text("Left")
    DSDivider(orientation: .vertical)
      .frame(height: 40)
    Text("Center")
    DSDivider(orientation: .vertical, thickness: 2, color: .blue)
      .frame(height: 40)
    Text("Right")
  }
  .padding()
}

#Preview("DSDivider - Colors") {
  VStack(spacing: DS.Spacing.md) {
    DSDivider(color: DS.Colors.separator)
    DSDivider(color: DS.Colors.accent)
    DSDivider(color: DS.Colors.destructive)
    DSDivider(color: DS.Colors.success)
    DSDivider(color: DS.Colors.warning)
  }
  .padding()
}
