//
//  FloatingActionButton.swift
//  Dispatch
//
//  Reusable floating action button for quick item creation.
//  System blue with haptic feedback on tap.
//

import SwiftUI

/// A floating action button for primary actions (e.g., creating new items).
/// Uses system blue for proper dark mode / accessibility behavior.
/// Includes haptic feedback on tap (iOS only).
///
/// Usage:
/// ```swift
/// FloatingActionButton {
///   showSheet = true
/// }
/// ```
struct FloatingActionButton: View {

  // MARK: Internal

  let action: () -> Void

  // Customization options with sensible defaults
  var icon = "plus"
  var size: CGFloat = DS.Spacing.floatingButtonSizeLarge // 56pt
  var foregroundColor = Color.white
  var accessibilityLabelText = "Add new item"

  var body: some View {
    Button {
      tapCount += 1
      action()
    } label: {
      Image(systemName: icon)
        .font(.system(size: scaledIconSize, weight: .semibold))
        .foregroundColor(foregroundColor)
        .frame(width: size, height: size)
        .background(backgroundColor)
        .clipShape(Circle())
        .dsShadow(DS.Shadows.elevated)
    }
    .buttonStyle(.plain)
    #if os(iOS)
      .sensoryFeedback(.impact(flexibility: .soft), trigger: tapCount)
    #endif
      .accessibilityLabel(accessibilityLabelText)
  }

  // MARK: Private

  /// Scaled large icon size for Dynamic Type support (base: 24pt, relative to title3)
  @ScaledMetric(relativeTo: .title3)
  private var scaledLargeIconSize: CGFloat = 24

  /// Scaled standard icon size for Dynamic Type support (base: 20pt, relative to body)
  @ScaledMetric(relativeTo: .body)
  private var scaledStandardIconSize: CGFloat = 20

  /// Haptic trigger - increments on each tap
  @State private var tapCount = 0

  /// Accent color for proper dark mode / accessibility behavior
  private var backgroundColor: Color {
    DS.Colors.accent
  }

  /// Icon size scales with button size and Dynamic Type
  private var scaledIconSize: CGFloat {
    size >= DS.Spacing.floatingButtonSizeLarge
      ? scaledLargeIconSize // 24pt base, scaled
      : scaledStandardIconSize // 20pt base, scaled
  }

}

// MARK: - Preview

#Preview("Floating Action Button") {
  ZStack(alignment: .bottomTrailing) {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    FloatingActionButton { }
      .padding()
  }
}

#Preview("FAB with Custom Icon") {
  ZStack(alignment: .bottomTrailing) {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    FloatingActionButton(action: { }, icon: "pencil")
      .padding()
  }
}

#Preview("FAB Small Size") {
  ZStack(alignment: .bottomTrailing) {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    FloatingActionButton(action: { }, size: DS.Spacing.floatingButtonSize)
      .padding()
  }
}
