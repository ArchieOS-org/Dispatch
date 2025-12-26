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
        HStack(spacing: DS.Spacing.sm) {
            // Colored Status Checkbox
            StatusCheckbox(
                isCompleted: item.isCompleted,
                color: roleColor,
                onToggle: onComplete
            )

            // Title
            Text(item.title)
                .font(DS.Typography.body)
                .strikethrough(item.isCompleted, color: DS.Colors.Text.tertiary)
                .foregroundColor(item.isCompleted ? DS.Colors.Text.tertiary : DS.Colors.Text.primary)
                .lineLimit(1)

            // User Tag (Inline with title)
            if case .claimedByOther(let user) = claimState {
                UserTag(user: user)
            } else if case .claimedByMe(let user) = claimState {
                UserTag(user: user)
            }

            Spacer()

            // Right side items
            HStack(spacing: DS.Spacing.sm) {
                // Due Date
                if let _ = item.dueDate {
                    DueDateBadge(dueDate: item.dueDate)
                }

                // Actions / Status
                if item.isSyncFailed {
                    SyncRetryButton(
                        errorMessage: item.lastSyncError,
                        isRetrying: isRetrying,
                        onRetry: {
                            isRetrying = true
                            onRetrySync()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isRetrying = false
                            }
                        }
                    )
                } else if case .unclaimed = claimState {
                    ClaimButton(
                        claimState: claimState,
                        style: .compact,
                        onClaim: onClaim,
                        onRelease: onRelease
                    )
                }
            }
        }
        .padding(.vertical, DS.Spacing.md)
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
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                HapticFeedback.medium()
                onComplete()
            } label: {
                Label("Complete", systemImage: "checkmark")
            }
            .tint(DS.Colors.success)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to view details. Swipe for more options.")
    }

    /// Color for the status checkbox based on role audience
    private var roleColor: Color {
        if item.audiences.contains(.admin) && item.audiences.contains(.marketing) {
            return DS.Colors.Text.primary // Mixed/Both (could be purple or distinct)
        } else if item.audiences.contains(.admin) {
            return DS.Colors.RoleColors.admin
        } else if item.audiences.contains(.marketing) {
            return DS.Colors.RoleColors.marketing
        }
        return DS.Colors.Text.tertiary // Default/None
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
