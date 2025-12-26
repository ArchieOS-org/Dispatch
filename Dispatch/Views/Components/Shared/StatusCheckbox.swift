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
    let isCompleted: Bool
    var color: Color = DS.Colors.Text.tertiary
    var onToggle: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onToggle) {
            ZStack {
                if isCompleted {
                    Circle()
                        .fill(color)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .strokeBorder(color, lineWidth: 1.5)
                }
            }
            .frame(width: 18, height: 18) // Match text height
            .scaleEffect(isCompleted ? 1.0 : 0.95)
            .animation(
                reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.6),
                value: isCompleted
            )
        }
        .buttonStyle(.plain)
        .frame(width: DS.Spacing.minTouchTarget, height: DS.Spacing.minTouchTarget) // Touch target remains large
        .accessibilityLabel(isCompleted ? "Completed" : "Not completed")
        .accessibilityHint("Double tap to toggle completion status")
        .accessibilityAddTraits(.isButton)
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
