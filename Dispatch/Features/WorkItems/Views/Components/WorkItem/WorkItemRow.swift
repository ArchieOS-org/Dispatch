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
/// - Type label, due date badge
/// - Overlapping assignee avatars (max 3 + "+N")
/// - Swipe actions for edit/delete
struct WorkItemRow: View {

  // MARK: Internal

  let item: WorkItem
  let userLookup: [UUID: User]

  // Closure-based actions (onTap removed - use NavigationLink wrapper instead)
  var onComplete: () -> Void = { }
  var onEdit: () -> Void = { }
  var onDelete: () -> Void = { }

  // Display options
  var hideDueDate = false
  var hideAssignees = false

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

        // Assignees
        if !hideAssignees {
          OverlappingAvatars(
            userIds: item.assigneeUserIds,
            users: userLookup,
            maxVisible: 3,
            size: .small
          )
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

  // MARK: Private

  private static let accessibilityDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
  }()

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

  private var accessibilityLabel: String {
    var parts = [String]()
    parts.append(item.typeLabel)
    parts.append(item.title)

    if item.isCompleted {
      parts.append("Completed")
    }

    if let dueDate = item.dueDate {
      parts.append("Due \(Self.accessibilityDateFormatter.string(from: dueDate))")
    }

    // Assignee description
    let assigneeNames = item.assigneeUserIds.compactMap { userLookup[$0]?.name }
    if assigneeNames.isEmpty, item.assigneeUserIds.isEmpty {
      parts.append("Unassigned")
    } else if assigneeNames.isEmpty {
      parts.append("Assigned to \(item.assigneeUserIds.count) unknown user\(item.assigneeUserIds.count == 1 ? "" : "s")")
    } else if assigneeNames.count == 1 {
      parts.append("Assigned to \(assigneeNames[0])")
    } else if assigneeNames.count == 2 {
      parts.append("Assigned to \(assigneeNames[0]) and \(assigneeNames[1])")
    } else {
      let allButLast = assigneeNames.dropLast().joined(separator: ", ")
      if let lastName = assigneeNames.last {
        parts.append("Assigned to \(allButLast), and \(lastName)")
      }
    }

    return parts.filter { !$0.isEmpty }.joined(separator: ", ")
  }
}

// MARK: - Preview

#Preview("Work Item Row") {
  let users: [UUID: User] = {
    var dict = [UUID: User]()
    let ids = [UUID(), UUID(), UUID(), UUID(), UUID()]
    let names = ["Alice Smith", "Bob Jones", "Carol White", "Dave Brown", "Eve Green"]
    for (id, name) in zip(ids, names) {
      dict[id] = User(
        id: id,
        name: name,
        email: "\(name.lowercased().replacingOccurrences(of: " ", with: "."))@example.com",
        userType: .realtor
      )
    }
    return dict
  }()

  let userIds = Array(users.keys)

  List {
    // Task example - multiple assignees
    WorkItemRow(
      item: .task(TaskItem(
        title: "Review quarterly report",
        taskDescription: "Go through Q4 numbers",
        dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
        declaredBy: UUID(),
        assigneeUserIds: Array(userIds.prefix(3))
      )),
      userLookup: users,
      onComplete: { },
      onEdit: { },
      onDelete: { }
    )

    // Activity example - unassigned
    WorkItemRow(
      item: .activity(Activity(
        title: "Client follow-up call",
        activityDescription: "Discuss contract terms",
        dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
        declaredBy: UUID(),
        assigneeUserIds: []
      )),
      userLookup: users,
      onComplete: { },
      onEdit: { },
      onDelete: { }
    )

    // Task example - single assignee
    WorkItemRow(
      item: .task(TaskItem(
        title: "My assigned task",
        taskDescription: "Working on this",
        declaredBy: UUID(),
        assigneeUserIds: [userIds[0]]
      )),
      userLookup: users,
      onComplete: { },
      onEdit: { },
      onDelete: { }
    )

    // Task example - overflow assignees (5)
    WorkItemRow(
      item: .task(TaskItem(
        title: "Team collaboration task",
        taskDescription: "Everyone involved",
        declaredBy: UUID(),
        assigneeUserIds: userIds
      )),
      userLookup: users,
      onComplete: { },
      onEdit: { },
      onDelete: { }
    )

    // Completed task
    WorkItemRow(
      item: .task(TaskItem(
        title: "Completed task example",
        taskDescription: "This is done",
        status: .completed,
        declaredBy: UUID(),
        assigneeUserIds: [userIds[1]]
      )),
      userLookup: users,
      onComplete: { },
      onEdit: { },
      onDelete: { }
    )

    // Overdue task
    WorkItemRow(
      item: .task(TaskItem(
        title: "Overdue task",
        taskDescription: "Should have been done",
        dueDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
        declaredBy: UUID(),
        assigneeUserIds: [userIds[2]]
      )),
      userLookup: users,
      onComplete: { },
      onEdit: { },
      onDelete: { }
    )
  }
  .listStyle(.plain)
}
