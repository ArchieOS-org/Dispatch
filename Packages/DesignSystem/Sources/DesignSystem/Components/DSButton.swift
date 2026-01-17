//
//  DSButton.swift
//  DesignSystem
//
//  Primary button component with floating action button variant.
//  Uses system blue with haptic feedback on iOS.
//

import SwiftUI

/// A floating action button for primary actions.
/// Uses system blue for proper dark mode / accessibility behavior.
/// Includes haptic feedback on tap (iOS only).
///
/// Usage:
/// ```swift
/// DSFloatingButton { showSheet = true }
/// DSFloatingButton(icon: "pencil", size: .regular) { startEditing() }
/// ```
public struct DSFloatingButton: View {

  // MARK: - Size

  /// Predefined sizes for the floating button
  public enum Size {
    /// Regular size (44pt) - standard touch target
    case regular
    /// Large size (56pt) - primary FAB
    case large

    var dimension: CGFloat {
      switch self {
      case .regular: DS.Spacing.floatingButtonSize
      case .large: DS.Spacing.floatingButtonSizeLarge
      }
    }

    var iconSize: CGFloat {
      switch self {
      case .regular: DS.Spacing.floatingButtonIconSize
      case .large: DS.Spacing.floatingButtonIconSizeLarge
      }
    }
  }

  // MARK: Lifecycle

  /// Creates a floating action button.
  /// - Parameters:
  ///   - icon: SF Symbol name. Defaults to "plus".
  ///   - size: Button size. Defaults to `.large`.
  ///   - foregroundColor: Icon color. Defaults to white.
  ///   - backgroundColor: Button background. Defaults to system blue.
  ///   - accessibilityLabel: VoiceOver label. Defaults to "Add".
  ///   - action: Action to perform when tapped.
  public init(
    icon: String = "plus",
    size: Size = .large,
    foregroundColor: Color = .white,
    backgroundColor: Color? = nil,
    accessibilityLabel: String = "Add",
    action: @escaping () -> Void
  ) {
    self.icon = icon
    self.size = size
    self.foregroundColor = foregroundColor
    self.customBackgroundColor = backgroundColor
    self.accessibilityLabelText = accessibilityLabel
    self.action = action
  }

  // MARK: Public

  public var body: some View {
    Button {
      tapCount += 1
      action()
    } label: {
      Image(systemName: icon)
        .font(.system(size: size.iconSize, weight: .semibold))
        .foregroundColor(foregroundColor)
        .frame(width: size.dimension, height: size.dimension)
        .background(resolvedBackgroundColor)
        .clipShape(Circle())
        .dsShadow(DS.Shadows.elevated)
    }
    .buttonStyle(.plain)
    #if os(iOS)
      .sensoryFeedback(.impact(flexibility: .soft), trigger: tapCount)
    #endif
      .accessibilityLabel(accessibilityLabelText)
  }

  // MARK: Internal

  let icon: String
  let size: Size
  let foregroundColor: Color
  let customBackgroundColor: Color?
  let accessibilityLabelText: String
  let action: () -> Void

  // MARK: Private

  @State private var tapCount = 0

  private var resolvedBackgroundColor: Color {
    if let custom = customBackgroundColor {
      return custom
    }
    #if os(iOS)
    return Color(uiColor: .systemBlue)
    #else
    return Color.blue
    #endif
  }

}

// MARK: - Preview

#Preview("DSFloatingButton - Default") {
  ZStack(alignment: .bottomTrailing) {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    DSFloatingButton { }
      .padding()
  }
}

#Preview("DSFloatingButton - Custom Icon") {
  ZStack(alignment: .bottomTrailing) {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    DSFloatingButton(icon: "pencil") { }
      .padding()
  }
}

#Preview("DSFloatingButton - Sizes") {
  ZStack(alignment: .bottomTrailing) {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    VStack(spacing: DS.Spacing.lg) {
      DSFloatingButton(size: .regular) { }
      DSFloatingButton(size: .large) { }
    }
    .padding()
  }
}

#Preview("DSFloatingButton - Colors") {
  VStack(spacing: DS.Spacing.lg) {
    HStack(spacing: DS.Spacing.lg) {
      DSFloatingButton(icon: "heart.fill", backgroundColor: .red) { }
      DSFloatingButton(icon: "star.fill", backgroundColor: .orange) { }
      DSFloatingButton(icon: "checkmark", backgroundColor: .green) { }
    }
  }
  .padding()
  .background(DS.Colors.Background.grouped)
}
