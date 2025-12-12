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
/// - Compact ClaimButton for claim/release actions
/// - Swipe actions for edit/delete
struct WorkItemRow: View {
    let item: WorkItem
    let claimState: ClaimState

    // Closure-based actions (onTap removed - use NavigationLink wrapper instead)
    var onComplete: () -> Void = {}
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}
    var onClaim: () -> Void = {}
    var onRelease: () -> Void = {}
    var onRetrySync: () -> Void = {}

    // State for retry animation
    @State private var isRetrying = false

    private static let accessibilityDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
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
                }
            }

            Spacer()

            // Show sync error indicator if failed, otherwise show claim button
            if item.isSyncFailed {
                SyncRetryButton(
                    errorMessage: item.lastSyncError,
                    isRetrying: isRetrying,
                    onRetry: {
                        isRetrying = true
                        onRetrySync()
                        // Reset after a delay (sync completion will trigger UI refresh)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isRetrying = false
                        }
                    }
                )
                .padding(.trailing, DS.Spacing.sm)
            } else {
                ClaimButton(
                    claimState: claimState,
                    style: .compact,
                    onClaim: onClaim,
                    onRelease: onRelease
                )
                .padding(.trailing, DS.Spacing.md)
            }
        }
        .padding(.vertical, DS.Spacing.sm)
        .contentShape(Rectangle())
        // NOTE: Removed .onTapGesture - it was competing with NavigationLink's gesture.
        // Navigation is now handled by wrapping WorkItemRow in NavigationLink at the call site.
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
            parts.append("Due \(Self.accessibilityDateFormatter.string(from: dueDate))")
        }
        switch claimState {
        case .unclaimed:
            parts.append("Unclaimed")
        case .claimedByMe:
            parts.append("Claimed by you")
        case .claimedByOther(let user):
            parts.append("Claimed by \(user.name)")
        }
        if item.isSyncFailed {
            parts.append("Sync failed")
            if let error = item.lastSyncError {
                parts.append(error)
            }
        }
        return parts.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview("Work Item Row") {
    let claimedUser = User(name: "John Doe", email: "john@example.com", userType: .admin)
    let otherUser = User(name: "Jane Smith", email: "jane@example.com", userType: .admin)

    List {
        // Task example - claimed by other
        WorkItemRow(
            item: .task(TaskItem(
                title: "Review quarterly report",
                taskDescription: "Go through Q4 numbers",
                priority: .high,
                declaredBy: UUID()
            )),
            claimState: .claimedByOther(user: otherUser),
            onComplete: {},
            onEdit: {},
            onDelete: {},
            onClaim: {},
            onRelease: {}
        )

        // Activity example - unclaimed
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
            claimState: .unclaimed,
            onComplete: {},
            onEdit: {},
            onDelete: {},
            onClaim: {},
            onRelease: {}
        )

        // Task example - claimed by me
        WorkItemRow(
            item: .task(TaskItem(
                title: "My claimed task",
                taskDescription: "Working on this",
                priority: .medium,
                declaredBy: UUID()
            )),
            claimState: .claimedByMe(user: claimedUser),
            onComplete: {},
            onEdit: {},
            onDelete: {},
            onClaim: {},
            onRelease: {}
        )

        // Completed task - unclaimed
        WorkItemRow(
            item: .task(TaskItem(
                title: "Completed task example",
                taskDescription: "This is done",
                priority: .low,
                status: .completed,
                declaredBy: UUID()
            )),
            claimState: .unclaimed,
            onComplete: {},
            onEdit: {},
            onDelete: {},
            onClaim: {},
            onRelease: {}
        )
    }
    .listStyle(.plain)
}
