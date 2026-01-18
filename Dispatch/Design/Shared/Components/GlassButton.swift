//
//  GlassButton.swift
//  Dispatch
//
//  A floating button with liquid glass styling for iOS 26+ with material fallback
//

import SwiftUI

/// A circular button with liquid glass styling.
/// Uses `glassEffect` on iOS 26+, falls back to `ultraThinMaterial` on earlier versions.
/// Used for the FAB and similar simple glass buttons.
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
        Circle()
          .fill(.clear)
          .frame(width: 56, height: 56)
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
