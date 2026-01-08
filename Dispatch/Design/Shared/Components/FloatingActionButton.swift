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
        .font(.system(size: iconSize, weight: .semibold))
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

  /// System blue for proper dark mode / accessibility behavior
  private var backgroundColor: Color {
    #if os(iOS)
    Color(uiColor: .systemBlue)
    #else
    Color.blue
    #endif
  }

  /// Icon size scales with button size
  private var iconSize: CGFloat {
    size >= DS.Spacing.floatingButtonSizeLarge
      ? DS.Spacing.floatingButtonIconSizeLarge // 24pt
      : DS.Spacing.floatingButtonIconSize // 20pt
  }

  /// Haptic trigger - increments on each tap
  @State private var tapCount = 0
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
