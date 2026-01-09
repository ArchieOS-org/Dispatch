//
//  SubtaskRow.swift
//  Dispatch
//
//  Subtasks Component - Single subtask row with checkbox
//  Created by Claude on 2025-12-06.
//

import SwiftUI

/// A row displaying a subtask with completion checkbox and title.
/// Supports toggle, edit, and delete actions.
struct SubtaskRow: View {

  // MARK: Internal

  let subtask: Subtask
  var onToggle: () -> Void = { }
  var onDelete: (() -> Void)?

  var body: some View {
    HStack(spacing: DS.Spacing.sm) {
      // Checkbox
      Button(action: onToggle) {
        Image(systemName: subtask.completed ? DS.Icons.StatusIcons.completed : DS.Icons.StatusIcons.open)
          .font(.system(size: 18))
          .foregroundColor(subtask.completed ? DS.Colors.success : DS.Colors.Text.tertiary)
          .scaleEffect(subtask.completed ? 1.0 : 0.95)
          .animation(
            reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.6),
            value: subtask.completed
          )
      }
      .buttonStyle(.plain)
      .frame(width: DS.Spacing.minTouchTarget, height: DS.Spacing.minTouchTarget)

      // Title
      Text(subtask.title)
        .font(DS.Typography.body)
        .foregroundColor(subtask.completed ? DS.Colors.Text.tertiary : DS.Colors.Text.primary)
        .strikethrough(subtask.completed, color: DS.Colors.Text.tertiary)
        .lineLimit(2)

      Spacer()

      // Delete button
      if let onDelete {
        Button(action: onDelete) {
          Image(systemName: DS.Icons.Action.delete)
            .font(.system(size: 14))
            .foregroundColor(DS.Colors.destructive)
        }
        .buttonStyle(.plain)
        .frame(width: DS.Spacing.minTouchTarget, height: DS.Spacing.minTouchTarget)
      }
    }
    .padding(.vertical, DS.Spacing.xxs)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(subtask.title), \(subtask.completed ? "completed" : "not completed")")
    .accessibilityHint("Double tap to toggle completion")
    .accessibilityAddTraits(.isButton)
  }

  // MARK: Private

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

}

// MARK: - Preview

#Preview("Subtask Rows") {
  VStack(spacing: 0) {
    SubtaskRow(
      subtask: Subtask(
        title: "Review the documentation",
        parentType: .task,
        parentId: UUID()
      ),
      onToggle: { },
      onDelete: { }
    )

    Divider()

    SubtaskRow(
      subtask: Subtask(
        title: "Completed subtask with longer text that might wrap",
        completed: true,
        parentType: .task,
        parentId: UUID()
      ),
      onToggle: { },
      onDelete: { }
    )

    Divider()

    SubtaskRow(
      subtask: Subtask(
        title: "No delete button",
        parentType: .task,
        parentId: UUID()
      ),
      onToggle: { }
    )
  }
  .padding()
}
