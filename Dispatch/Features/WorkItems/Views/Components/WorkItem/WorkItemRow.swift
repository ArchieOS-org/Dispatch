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
  var onComplete: () -> Void = { }
  var onEdit: () -> Void = { }
  var onDelete: () -> Void = { }
  var onClaim: () -> Void = { }
  var onRelease: () -> Void = { }

  // New property
  var hideDueDate = false
  var hideClaimButton = false

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  // MARK: - Computed Properties

  private var isOverdue: Bool {
    guard let date = item.dueDate else { return false }
    // An item is overdue if its due date is before the start of today
    return date < Calendar.current.startOfDay(for: Date())
  }

  private var overdueText: String {
    guard let date = item.dueDate else { return "" }
    let startToday = Calendar.current.startOfDay(for: Date())
    let startDue = Calendar.current.startOfDay(for: date)
    let days = Calendar.current.dateComponents([.day], from: startDue, to: startToday).day ?? 0

    if days < 7 {
      let formatter = DateFormatter()
      formatter.dateFormat = "EEE"
      return formatter.string(from: date)
    }

    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter.string(from: date)
  }

  private static let accessibilityDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
  }()

  var body: some View {
    HStack(spacing: 6) {
      // Colored Status Checkbox
      StatusCheckbox(
        isCompleted: item.isCompleted,
        color: DS.Colors.Text.tertiary,
        isCircle: item.isTask,
        onToggle: onComplete
      )

      // Title
      Text(item.title)
        .font(DS.Typography.body)
        .strikethrough(item.isCompleted, color: DS.Colors.Text.tertiary)
        .foregroundColor(item.isCompleted ? DS.Colors.Text.tertiary : DS.Colors.Text.primary)
        .lineLimit(1)


      Spacer()

      // Right side items
      HStack(spacing: DS.Spacing.sm) {
        // Due Date (Right) - normal or overdue
        if let date = item.dueDate, !hideDueDate {
          if isOverdue {
            // Overdue: flag with date
            HStack(spacing: 4) {
              Image(systemName: "flag.fill")
              Text(overdueText)
            }
            .font(DS.Typography.caption)
            .foregroundStyle(.red)
          } else {
            // Normal: date pill
            DatePill(date: date)
          }
        }

        // Actions / Claim status
        switch claimState {
        case .claimedByOther(let user):
          // Show who claimed it in the same slot where the claim/unclaim control normally appears
          if !hideClaimButton {
            UserTag(user: user)
          }
        case .unclaimed, .claimedByMe:
          // Show claim/unclaim control for items you can act on
          if !hideClaimButton {
            ClaimButton(
              claimState: claimState,
              style: .compact,
              onClaim: onClaim,
              onRelease: onRelease
            )
          }
        }
      }
    }
    .padding(.vertical, DS.Spacing.listRowPadding)
    .listRowSeparator(.hidden)
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

  private var accessibilityLabel: String {
    var parts = [String]()
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
      onComplete: { },
      onEdit: { },
      onDelete: { },
      onClaim: { },
      onRelease: { }
    )

    // Activity example - unclaimed
    WorkItemRow(
      item: .activity(Activity(
        title: "Client follow-up call",
        activityDescription: "Discuss contract terms",
        type: .call,
        priority: .medium,
        declaredBy: UUID()
      )),
      claimState: .unclaimed,
      onComplete: { },
      onEdit: { },
      onDelete: { },
      onClaim: { },
      onRelease: { }
    )

    // Task example - claimed by me (shows unclaim control only)
    WorkItemRow(
      item: .task(TaskItem(
        title: "My claimed task",
        taskDescription: "Working on this",
        priority: .medium,
        declaredBy: UUID()
      )),
      claimState: .claimedByMe(user: claimedUser),
      onComplete: { },
      onEdit: { },
      onDelete: { },
      onClaim: { },
      onRelease: { }
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
      onComplete: { },
      onEdit: { },
      onDelete: { },
      onClaim: { },
      onRelease: { }
    )
  }
  .listStyle(.plain)
}
