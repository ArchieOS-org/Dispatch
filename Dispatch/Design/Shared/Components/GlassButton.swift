//
//  GlassButton.swift
//  Dispatch
//
//  A floating button with liquid glass styling for iOS 26+ with material fallback
//
//  iOS 26 Glass Styling:
//  - iOS 26+: Uses native `glassCircleBackground()` for Liquid Glass
//  - Pre-iOS 26: Falls back to `ultraThinMaterial` with shadow
//
//  Glass styling is handled by the DesignSystem's GlassEffect modifiers,
//  which automatically apply native glass on iOS 26+ with material fallback.
//

import DesignSystem
import SwiftUI

/// A circular button with liquid glass styling.
/// Uses `glassCircleBackground()` which applies native glass on iOS 26+, material fallback on earlier versions.
/// Used for secondary floating buttons that need a glass appearance.
///
/// iOS 26 Glass Styling:
/// - iOS 26+: Native Liquid Glass via `glassCircleBackground()`
/// - Pre-iOS 26: Falls back to `ultraThinMaterial` with shadow
struct GlassButton: View {

  // MARK: Internal

  let icon: String
  let accessibilityLabel: String
  let action: () -> Void
  var isFiltered = false

  var body: some View {
    Button(action: action) {
      ZStack(alignment: .topTrailing) {
        // Glass background on container, not icon
        // iOS 26+: Native Liquid Glass via glassCircleBackground()
        // Pre-iOS 26: Falls back to ultraThinMaterial with shadow
        Circle()
          .fill(.clear)
          .frame(width: DS.Spacing.floatingButtonSizeLarge, height: DS.Spacing.floatingButtonSizeLarge)
          .glassCircleBackground()
          .overlay {
            Image(systemName: icon)
              .font(.system(size: iconSize, weight: .semibold))
              .foregroundStyle(.primary)
          }

        // Subtle dot indicator when filtered
        if isFiltered {
          Circle()
            .fill(.primary.opacity(0.6))
            .frame(width: 8, height: 8)
            .offset(x: -4, y: 4)
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityAddTraits(.isButton)
  }

  // MARK: Private

  /// Scaled icon size for Dynamic Type support (base: 24pt, relative to title3)
  @ScaledMetric(relativeTo: .title3)
  private var iconSize: CGFloat = 24

}

// MARK: - Previews

#Preview("Glass Button - Default") {
  ZStack {
    Color.blue.opacity(0.3)
      .ignoresSafeArea()

    GlassButton(icon: "plus", accessibilityLabel: "Add item", action: { })
  }
}

#Preview("Glass Button - Filtered") {
  ZStack {
    Color.blue.opacity(0.3)
      .ignoresSafeArea()

    GlassButton(icon: "plus", accessibilityLabel: "Add item", action: { }, isFiltered: true)
  }
}
