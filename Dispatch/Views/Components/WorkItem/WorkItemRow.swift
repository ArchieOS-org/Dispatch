//
//  WorkItemRow.swift
//  Dispatch
//
//  WorkItem Component - List row for tasks/activities
//  Created by Claude on 2025-12-06.
//

import SwiftUI

/// A list row displaying a work item (task or activity) with:
/// - Status checkbox
/// - Title with strikethrough when completed
/// - Type label, due date badge, priority dot
/// - Claimed user avatar
/// - Swipe actions for edit/delete
struct WorkItemRow: View {
    let item: WorkItem
    let claimedByUser: User?

    // Closure-based actions
    var onTap: () -> Void = {}
    var onComplete: () -> Void = {}
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.md) {
                // Status checkbox
                StatusCheckbox(isCompleted: item.isCompleted, onToggle: onComplete)

                // Content
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    // Title row
                    HStack {
                        Text(item.title)
                            .font(DS.Typography.headline)
                            .strikethrough(item.isCompleted, color: DS.Colors.Text.tertiary)
                            .foregroundColor(item.isCompleted ? DS.Colors.Text.tertiary : DS.Colors.Text.primary)
                            .lineLimit(1)

                        Spacer()

                        PriorityDot(priority: item.priority)
                    }

                    // Metadata row
                    HStack(spacing: DS.Spacing.sm) {
                        // Type label with icon
                        HStack(spacing: DS.Spacing.xxs) {
                            Image(systemName: item.typeIcon)
                                .font(.system(size: 10))
                            Text(item.typeLabel)
                                .font(DS.Typography.caption)
                        }
                        .foregroundColor(DS.Colors.Text.secondary)

                        DueDateBadge(dueDate: item.dueDate)

                        // Subtask progress (if any)
                        if item.hasSubtasks {
                            HStack(spacing: DS.Spacing.xxs) {
                                Image(systemName: DS.Icons.Entity.subtask)
                                    .font(.system(size: 10))
                                Text(item.subtaskProgressText)
                                    .font(DS.Typography.caption)
                            }
                            .foregroundColor(DS.Colors.Text.tertiary)
                        }

                        Spacer()

                        // Claimed user avatar
                        if claimedByUser != nil {
                            UserAvatar(user: claimedByUser, size: .small)
                        }
                    }
                }
            }
            .padding(.vertical, DS.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: DS.Icons.Action.delete)
            }

            Button(action: onEdit) {
                Label("Edit", systemImage: DS.Icons.Action.edit)
            }
            .tint(DS.Colors.info)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to view details. Swipe for more options.")
    }

    private var accessibilityLabel: String {
        var parts: [String] = []
        parts.append(item.typeLabel)
        parts.append(item.title)
        parts.append(item.isCompleted ? "Completed" : "")
        parts.append("\(item.priority.rawValue) priority")
        if let dueDate = item.dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            parts.append("Due \(formatter.string(from: dueDate))")
        }
        if let user = claimedByUser {
            parts.append("Claimed by \(user.name)")
        }
        return parts.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview("Work Item Row") {
    List {
        // Task example
        WorkItemRow(
            item: .task(TaskItem(
                title: "Review quarterly report",
                taskDescription: "Go through Q4 numbers",
                priority: .high,
                declaredBy: UUID()
            )),
            claimedByUser: User(name: "John Doe", email: "john@example.com", userType: .admin),
            onTap: {},
            onComplete: {},
            onEdit: {},
            onDelete: {}
        )

        // Activity example
        WorkItemRow(
            item: .activity({
                let a = Activity(
                    title: "Client follow-up call",
                    activityDescription: "Discuss contract terms",
                    type: .call,
                    priority: .medium,
                    declaredBy: UUID()
                )
                return a
            }()),
            claimedByUser: nil,
            onTap: {},
            onComplete: {},
            onEdit: {},
            onDelete: {}
        )

        // Completed task
        WorkItemRow(
            item: .task(TaskItem(
                title: "Completed task example",
                taskDescription: "This is done",
                priority: .low,
                status: .completed,
                declaredBy: UUID()
            )),
            claimedByUser: nil,
            onTap: {},
            onComplete: {},
            onEdit: {},
            onDelete: {}
        )
    }
    .listStyle(.plain)
}
