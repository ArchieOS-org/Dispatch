//
//  WorkItemDetailView.swift
//  Dispatch
//
//  WorkItem Component - Full detail view
//  Refactored for Layout Unification (StandardScreen)
//

import SwiftUI

/// Full detail view for a work item (task or activity).
struct WorkItemDetailView: View {

  // MARK: Internal

  let item: WorkItem
  let claimState: ClaimState
  let userLookup: (UUID) -> User?

  // Actions
  var onComplete: () -> Void = { }
  var onClaim: () -> Void = { }
  var onRelease: () -> Void = { }
  var onEditNote: ((Note) -> Void)?
  var onDeleteNote: ((Note) -> Void)?
  var onAddNote: ((String) -> Void)?
  var onToggleSubtask: ((Subtask) -> Void)?
  var onDeleteSubtask: ((Subtask) -> Void)?
  var onAddSubtask: (() -> Void)?

  var body: some View {
    StandardScreen(title: item.title, layout: .column, scroll: .automatic) {
      content
    }
  }

  // MARK: Private

  // showNoteInput removed - always-visible composer uses internal state

  private static let detailDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()

  /// Environment
  @EnvironmentObject private var lensState: LensState

  private var content: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.xl) {
      // Header / Priority / Due Date
      // Moved from CollapsibleHeader to content top
      HStack(spacing: DS.Spacing.sm) {
        PriorityDot(priority: item.priority)
        DueDateBadge(dueDate: item.dueDate)
        Spacer()
      }
      .padding(.bottom, DS.Spacing.sm)

      // Description Section
      descriptionSection

      // Metadata Section
      metadataSection

      // Subtasks Section
      subtasksSection

      // Notes Section
      notesSection
    }
    .padding(.vertical, DS.Spacing.md)
  }

  private var descriptionSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      sectionHeader("Description")

      if item.itemDescription.isEmpty {
        Text("No description provided")
          .font(DS.Typography.body)
          .foregroundColor(DS.Colors.Text.tertiary)
          .italic()
      } else {
        Text(item.itemDescription)
          .font(DS.Typography.body)
          .foregroundColor(DS.Colors.Text.primary)
      }
    }
    .padding(DS.Spacing.md)
    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    .background(DS.Colors.Background.card)
    .cornerRadius(DS.Spacing.radiusCard)
  }

  private var metadataSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      sectionHeader("Details")

      VStack(spacing: DS.Spacing.sm) {
        // Type
        metadataRow(
          icon: item.typeIcon,
          label: "Type",
          value: item.typeLabel
        )

        Divider()

        // Status
        metadataRow(
          icon: item.statusIcon,
          label: "Status",
          value: item.statusText,
          valueColor: item.statusColor
        )

        Divider()

        // Priority
        HStack {
          Image(systemName: DS.Icons.priorityDot)
            .foregroundColor(DS.Colors.Text.secondary)
            .frame(width: 24)
          Text("Priority")
            .font(DS.Typography.bodySecondary)
            .foregroundColor(DS.Colors.Text.secondary)
          Spacer()
          HStack(spacing: DS.Spacing.xs) {
            PriorityDot(priority: item.priority)
            Text(item.priority.rawValue.capitalized)
              .font(DS.Typography.body)
              .foregroundColor(item.priority.color)
          }
        }

        Divider()

        // Created by
        if let creator = userLookup(item.declaredBy) {
          HStack {
            Image(systemName: DS.Icons.Entity.user)
              .foregroundColor(DS.Colors.Text.secondary)
              .frame(width: 24)
            Text("Created by")
              .font(DS.Typography.bodySecondary)
              .foregroundColor(DS.Colors.Text.secondary)
            Spacer()
            HStack(spacing: DS.Spacing.xs) {
              UserAvatar(user: creator, size: .small)
              Text(creator.name)
                .font(DS.Typography.body)
            }
          }

          Divider()
        }

        // Created at
        metadataRow(
          icon: DS.Icons.Time.clock,
          label: "Created",
          value: formatDate(item.createdAt)
        )

        Divider()

        // Updated at
        metadataRow(
          icon: DS.Icons.Time.clock,
          label: "Updated",
          value: formatDate(item.updatedAt)
        )

        Divider()

        // Claim section
        HStack {
          Image(systemName: DS.Icons.Claim.unclaimed)
            .foregroundColor(DS.Colors.Text.secondary)
            .frame(width: 24)
          Text("Assignment")
            .font(DS.Typography.bodySecondary)
            .foregroundColor(DS.Colors.Text.secondary)
          Spacer()
          ClaimButton(
            claimState: claimState,
            onClaim: onClaim,
            onRelease: onRelease
          )
        }
      }
    }
    .padding(DS.Spacing.md)
    .background(DS.Colors.Background.card)
    .cornerRadius(DS.Spacing.radiusCard)
  }

  private var subtasksSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      SubtasksList(
        subtasks: item.subtasks,
        onToggle: onToggleSubtask,
        onDelete: onDeleteSubtask,
        onAdd: onAddSubtask
      )
    }
    .padding(DS.Spacing.md)
    .background(DS.Colors.Background.card)
    .cornerRadius(DS.Spacing.radiusCard)
  }

  private var notesSection: some View {
    NotesSection(
      notes: item.notes,
      userLookup: userLookup,
      onSave: { content in onAddNote?(content) },
      onDelete: onDeleteNote
    )
  }

  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(DS.Typography.headline)
      .foregroundColor(DS.Colors.Text.primary)
  }

  private func metadataRow(
    icon: String,
    label: String,
    value: String,
    valueColor: Color = DS.Colors.Text.primary
  ) -> some View {
    HStack {
      Image(systemName: icon)
        .foregroundColor(DS.Colors.Text.secondary)
        .frame(width: 24)
      Text(label)
        .font(DS.Typography.bodySecondary)
        .foregroundColor(DS.Colors.Text.secondary)
      Spacer()
      Text(value)
        .font(DS.Typography.body)
        .foregroundColor(valueColor)
    }
  }

  private func formatDate(_ date: Date) -> String {
    Self.detailDateFormatter.string(from: date)
  }
}

// MARK: - Preview

#Preview("Work Item Detail View") {
  let sampleTask = TaskItem(
    title: "Review quarterly report",
    taskDescription: "Go through the Q4 numbers and prepare a summary for the board meeting.",
    priority: .high,
    declaredBy: UUID()
  )

  let sampleUser = User(name: "John Doe", email: "john@example.com", userType: .admin)

  NavigationStack {
    WorkItemDetailView(
      item: .task(sampleTask),
      claimState: .claimedByMe(user: sampleUser),
      userLookup: { _ in sampleUser },
      onComplete: { },
      onClaim: { },
      onRelease: { },
      onAddNote: { _ in },
      onAddSubtask: { }
    )
  }
  .environmentObject(LensState())
}
