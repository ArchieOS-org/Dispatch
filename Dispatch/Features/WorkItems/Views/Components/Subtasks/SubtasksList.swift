//
//  SubtasksList.swift
//  Dispatch
//
//  Subtasks Component - List of subtasks with progress bar and add button
//  Created by Claude on 2025-12-06.
//

import SwiftUI

/// A list of subtasks with a progress indicator and add button.
/// Displays completion progress and supports adding new subtasks.
struct SubtasksList: View {

  // MARK: Internal

  let subtasks: [Subtask]
  var onToggle: ((Subtask) -> Void)?
  var onDelete: ((Subtask) -> Void)?
  var onAdd: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      // Header with progress
      if !subtasks.isEmpty {
        HStack {
          Text("Subtasks")
            .font(DS.Typography.headline)
            .foregroundColor(DS.Colors.Text.primary)

          Spacer()

          Text("\(completedCount)/\(subtasks.count)")
            .font(DS.Typography.caption)
            .foregroundColor(DS.Colors.Text.secondary)
        }

        // Progress bar
        GeometryReader { geometry in
          ZStack(alignment: .leading) {
            // Background
            RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall)
              .fill(DS.Colors.Background.secondary)
              .frame(height: 6)

            // Progress fill
            RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall)
              .fill(progress == 1.0 ? DS.Colors.success : DS.Colors.accent)
              .frame(width: geometry.size.width * progress, height: 6)
              .animation(.easeInOut(duration: 0.3), value: progress)
          }
        }
        .frame(height: 6)
      }

      // Subtask rows
      if subtasks.isEmpty {
        emptyState
      } else {
        VStack(spacing: 0) {
          ForEach(Array(subtasks.enumerated()), id: \.element.id) { index, subtask in
            SubtaskRow(
              subtask: subtask,
              onToggle: { onToggle?(subtask) },
              onDelete: onDelete != nil ? { onDelete?(subtask) } : nil,
            )

            if index < subtasks.count - 1 {
              Divider()
                .padding(.leading, DS.Spacing.minTouchTarget)
            }
          }
        }
      }

      // Add button
      if let onAdd {
        Button(action: onAdd) {
          HStack(spacing: DS.Spacing.xs) {
            Image(systemName: DS.Icons.Action.add)
            Text("Add Subtask")
          }
          .font(DS.Typography.bodySecondary)
          .foregroundColor(DS.Colors.accent)
        }
        .buttonStyle(.plain)
        .padding(.top, DS.Spacing.xs)
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Subtasks, \(completedCount) of \(subtasks.count) completed")
  }

  // MARK: Private

  private var completedCount: Int {
    subtasks.count(where: { $0.completed })
  }

  private var progress: Double {
    guard !subtasks.isEmpty else { return 0 }
    return Double(completedCount) / Double(subtasks.count)
  }

  private var emptyState: some View {
    VStack(spacing: DS.Spacing.xs) {
      Text("No subtasks")
        .font(DS.Typography.bodySecondary)
        .foregroundColor(DS.Colors.Text.secondary)
      Text("Break down this item into smaller steps")
        .font(DS.Typography.caption)
        .foregroundColor(DS.Colors.Text.tertiary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, DS.Spacing.md)
  }
}

// MARK: - Preview

#Preview("Subtasks List") {
  let sampleSubtasks: [Subtask] = [
    Subtask(title: "Research the topic", completed: true, parentType: .task, parentId: UUID()),
    Subtask(title: "Write the first draft", completed: true, parentType: .task, parentId: UUID()),
    Subtask(title: "Review and edit", parentType: .task, parentId: UUID()),
    Subtask(title: "Final submission", parentType: .task, parentId: UUID())
  ]

  return ScrollView {
    VStack(spacing: DS.Spacing.xl) {
      Text("With Subtasks").font(DS.Typography.caption)
      SubtasksList(
        subtasks: sampleSubtasks,
        onToggle: { _ in },
        onDelete: { _ in },
        onAdd: { },
      )

      Divider()

      Text("Empty State").font(DS.Typography.caption)
      SubtasksList(
        subtasks: [],
        onAdd: { },
      )

      Divider()

      Text("All Complete").font(DS.Typography.caption)
      SubtasksList(
        subtasks: [
          Subtask(title: "Research the topic", completed: true, parentType: .task, parentId: UUID()),
          Subtask(title: "Write the first draft", completed: true, parentType: .task, parentId: UUID()),
          Subtask(title: "Review and edit", completed: true, parentType: .task, parentId: UUID()),
          Subtask(title: "Final submission", completed: true, parentType: .task, parentId: UUID())
        ],
        onToggle: { _ in },
      )
    }
    .padding()
  }
}
