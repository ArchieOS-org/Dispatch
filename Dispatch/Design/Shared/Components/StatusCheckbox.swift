//
//  StatusCheckbox.swift
//  Dispatch
//
//  Shared Component - Animated completion toggle checkbox
//  Created by Claude on 2025-12-06.
//

import SwiftUI

/// An animated checkbox for toggling completion status.
/// Shows open circle when incomplete, filled checkmark when complete.
struct StatusCheckbox: View {

  // MARK: Internal

  let isCompleted: Bool
  var color: Color = DS.Colors.Text.tertiary
  var isCircle = false
  var onToggle: () -> Void = { }

  var body: some View {
    Button(action: onToggle) {
      Image(systemName: iconName)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(color)
        .frame(width: 14, height: 14) // Match text visual height
        .scaleEffect(isCompleted ? 1.0 : 0.95)
        .animation(
          reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.6),
          value: isCompleted,
        )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(isCompleted ? "Completed" : "Not completed")
    .accessibilityHint("Double tap to toggle completion status")
    .accessibilityAddTraits(.isButton)
  }

  // MARK: Private

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var iconName: String {
    if isCircle {
      isCompleted ? "checkmark.circle.fill" : "circle"
    } else {
      isCompleted ? "checkmark.square.fill" : "square"
    }
  }
}

// MARK: - Preview

#Preview("Status Checkbox") {
  struct PreviewWrapper: View {
    @State private var isCompleted = false

    var body: some View {
      VStack(spacing: DS.Spacing.lg) {
        HStack(spacing: DS.Spacing.md) {
          StatusCheckbox(isCompleted: false)
          Text("Incomplete")
        }

        HStack(spacing: DS.Spacing.md) {
          StatusCheckbox(isCompleted: true)
          Text("Completed")
        }

        Divider()

        HStack(spacing: DS.Spacing.md) {
          StatusCheckbox(isCompleted: isCompleted, color: .blue) {
            isCompleted.toggle()
          }
          Text("Interactive: \(isCompleted ? "Done" : "Tap me")")
        }
      }
      .padding()
    }
  }

  return PreviewWrapper()
}
