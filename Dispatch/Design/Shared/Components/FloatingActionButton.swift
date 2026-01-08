//
//  FloatingActionButton.swift
//  Dispatch
//
//  Reusable floating action button for quick item creation
//

import SwiftUI

/// A floating action button that appears in the bottom-right corner of list views.
/// Tapping triggers an action (typically opening a sheet for item creation).
///
/// Usage:
/// ```swift
/// .overlay(alignment: .bottomTrailing) {
///     FloatingActionButton {
///         showSheet = true
///     }
/// }
/// ```
struct FloatingActionButton: View {
  let action: () -> Void

  // Customization options with sensible defaults
  var icon = "plus"
  var size: CGFloat = 56
  var backgroundColor: Color = DS.Colors.accent
  var foregroundColor = Color.white
  var accessibilityLabelText = "Add new item"

  var body: some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: 24, weight: .semibold))
        .foregroundColor(foregroundColor)
        .frame(width: size, height: size)
        .background(backgroundColor)
        .clipShape(Circle())
        .dsShadow(DS.Shadows.elevated)
    }
    .padding(DS.Spacing.lg)
    .accessibilityLabel(accessibilityLabelText)
  }
}

// MARK: - Preview

#Preview("Floating Action Button") {
  ZStack(alignment: .bottomTrailing) {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    FloatingActionButton { }
  }
}

#Preview("FAB with Custom Icon") {
  ZStack(alignment: .bottomTrailing) {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    FloatingActionButton(action: { }, icon: "pencil")
  }
}
