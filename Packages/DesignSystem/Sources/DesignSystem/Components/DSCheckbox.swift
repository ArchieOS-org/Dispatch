//
//  DSCheckbox.swift
//  DesignSystem
//
//  Animated checkbox for toggling completion status.
//  Domain-agnostic toggle with optional circular variant.
//

import SwiftUI

/// An animated checkbox for toggling completion/selection status.
/// Shows open shape when unchecked, filled checkmark when checked.
///
/// Usage:
/// ```swift
/// DSCheckbox(isChecked: isCompleted) { isCompleted.toggle() }
/// DSCheckbox(isChecked: isDone, isCircle: true, color: .blue) { isDone.toggle() }
/// ```
public struct DSCheckbox: View {

  // MARK: Lifecycle

  /// Creates a checkbox with the specified state and appearance.
  /// - Parameters:
  ///   - isChecked: Whether the checkbox is currently checked.
  ///   - isCircle: If true, uses circle shape instead of square. Defaults to false.
  ///   - color: The checkbox color. Defaults to tertiary text.
  ///   - size: The icon size. Defaults to 14pt.
  ///   - accessibilityLabel: Custom accessibility label. Defaults to checked/unchecked state.
  ///   - onToggle: Action to perform when tapped.
  public init(
    isChecked: Bool,
    isCircle: Bool = false,
    color: Color = DS.Colors.Text.tertiary,
    size: CGFloat = 14,
    accessibilityLabel: String? = nil,
    onToggle: @escaping () -> Void = { }
  ) {
    self.isChecked = isChecked
    self.isCircle = isCircle
    self.color = color
    self.size = size
    self.customAccessibilityLabel = accessibilityLabel
    self.onToggle = onToggle
  }

  // MARK: Public

  public var body: some View {
    Button(action: onToggle) {
      Image(systemName: iconName)
        .font(.system(size: size, weight: .medium))
        .foregroundStyle(color)
        .frame(width: size, height: size)
        .scaleEffect(isChecked ? 1.0 : 0.95)
        .animation(
          reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.6),
          value: isChecked
        )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabelText)
    .accessibilityHint("Double tap to toggle")
    .accessibilityAddTraits(.isButton)
  }

  // MARK: Internal

  let isChecked: Bool
  let isCircle: Bool
  let color: Color
  let size: CGFloat
  let customAccessibilityLabel: String?
  let onToggle: () -> Void

  // MARK: Private

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var iconName: String {
    if isCircle {
      isChecked ? "checkmark.circle.fill" : "circle"
    } else {
      isChecked ? "checkmark.square.fill" : "square"
    }
  }

  private var accessibilityLabelText: String {
    customAccessibilityLabel ?? (isChecked ? "Checked" : "Unchecked")
  }

}

// MARK: - Preview

#Preview("DSCheckbox - States") {
  VStack(spacing: DS.Spacing.lg) {
    HStack(spacing: DS.Spacing.md) {
      DSCheckbox(isChecked: false)
      Text("Unchecked")
    }

    HStack(spacing: DS.Spacing.md) {
      DSCheckbox(isChecked: true)
      Text("Checked")
    }

    Divider()

    HStack(spacing: DS.Spacing.md) {
      DSCheckbox(isChecked: false, isCircle: true)
      Text("Circle Unchecked")
    }

    HStack(spacing: DS.Spacing.md) {
      DSCheckbox(isChecked: true, isCircle: true)
      Text("Circle Checked")
    }
  }
  .padding()
}

#Preview("DSCheckbox - Interactive") {
  struct PreviewWrapper: View {
    @State private var isChecked = false

    var body: some View {
      VStack(spacing: DS.Spacing.lg) {
        HStack(spacing: DS.Spacing.md) {
          DSCheckbox(isChecked: isChecked, color: .blue) {
            isChecked.toggle()
          }
          Text("Tap me: \(isChecked ? "Done" : "Not done")")
        }

        HStack(spacing: DS.Spacing.md) {
          DSCheckbox(isChecked: isChecked, isCircle: true, color: .green) {
            isChecked.toggle()
          }
          Text("Circle variant")
        }
      }
      .padding()
    }
  }

  return PreviewWrapper()
}

#Preview("DSCheckbox - Sizes") {
  HStack(spacing: DS.Spacing.lg) {
    VStack(spacing: DS.Spacing.xs) {
      DSCheckbox(isChecked: true, size: 12)
      Text("12pt").font(DS.Typography.caption)
    }
    VStack(spacing: DS.Spacing.xs) {
      DSCheckbox(isChecked: true, size: 14)
      Text("14pt").font(DS.Typography.caption)
    }
    VStack(spacing: DS.Spacing.xs) {
      DSCheckbox(isChecked: true, size: 18)
      Text("18pt").font(DS.Typography.caption)
    }
    VStack(spacing: DS.Spacing.xs) {
      DSCheckbox(isChecked: true, size: 24)
      Text("24pt").font(DS.Typography.caption)
    }
  }
  .padding()
}
