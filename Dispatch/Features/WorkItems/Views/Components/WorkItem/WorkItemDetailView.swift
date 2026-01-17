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
  let userLookup: [UUID: User]
  let currentUserId: UUID
  let availableUsers: [User]

  // Actions
  var onComplete: () -> Void = { }
  var onAssigneesChanged: (([UUID]) -> Void)?
  var onEditNote: ((Note) -> Void)?
  var onDeleteNote: ((Note) -> Void)?
  var onAddNote: ((String) -> Void)?

  var body: some View {
    StandardScreen(title: item.title, layout: .column, scroll: .automatic) {
      content
    }
    .task {
      // Refresh notes for this work item when view appears
      let parentType: ParentType = item.isTask ? .task : .activity
      await syncManager.refreshNotesForParent(parentId: item.id, parentType: parentType)
    }
    .sheet(isPresented: $showAssigneePicker) {
      assigneePickerSheet
    }
  }

  // MARK: Private

  private static let detailDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()

  @State private var showAssigneePicker = false
  @State private var selectedAssigneeIds: Set<UUID> = []

  /// Environment
  @EnvironmentObject private var lensState: LensState
  @EnvironmentObject private var syncManager: SyncManager

  /// Whether current user is assigned to this item
  private var isAssignedToMe: Bool {
    item.assigneeUserIds.contains(currentUserId)
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header / Due Date
      HStack(spacing: DS.Spacing.sm) {
        DueDateBadge(dueDate: item.dueDate)
        Spacer()
      }

      Color.clear.frame(height: DS.Spacing.lg)

      // Description Section
      descriptionSection

      Color.clear.frame(height: DS.Spacing.lg)

      // Metadata Section
      metadataSection

      Color.clear.frame(height: DS.Spacing.lg)

      // Notes Section
      notesSection
    }
    .padding(.bottom, DS.Spacing.md)
  }

  private var descriptionSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      sectionHeader("Description")

      Divider().padding(.top, DS.Spacing.sm)

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

      Divider().padding(.top, DS.Spacing.sm)
    }
  }

  private var metadataSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      sectionHeader("Details")

      Divider().padding(.top, DS.Spacing.sm)

      // Type
      metadataRow(
        icon: item.typeIcon,
        label: "Type",
        value: item.typeLabel
      )

      Divider().padding(.top, DS.Spacing.sm)

      // Status
      metadataRow(
        icon: item.statusIcon,
        label: "Status",
        value: item.statusText,
        valueColor: item.statusColor
      )

      Divider().padding(.top, DS.Spacing.sm)

      // Assignees
      assigneesRow

      Divider().padding(.top, DS.Spacing.sm)

      // Created by
      if let creator = userLookup[item.declaredBy] {
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

        Divider().padding(.top, DS.Spacing.sm)
      }

      // Created at
      metadataRow(
        icon: DS.Icons.Time.clock,
        label: "Created",
        value: formatDate(item.createdAt)
      )

      Divider().padding(.top, DS.Spacing.sm)

      // Updated at
      metadataRow(
        icon: DS.Icons.Time.clock,
        label: "Updated",
        value: formatDate(item.updatedAt)
      )

      Divider().padding(.top, DS.Spacing.sm)
    }
  }

  private var notesSection: some View {
    NotesSection(
      notes: item.notes,
      userLookup: { userLookup[$0] },
      onSave: { content in onAddNote?(content) },
      onDelete: onDeleteNote
    )
  }

  private var assigneesRow: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      HStack {
        Image(systemName: "person.2")
          .foregroundColor(DS.Colors.Text.secondary)
          .frame(width: 24)
        Text("Assigned to")
          .font(DS.Typography.bodySecondary)
          .foregroundColor(DS.Colors.Text.secondary)
        Spacer()

        Button {
          selectedAssigneeIds = Set(item.assigneeUserIds)
          showAssigneePicker = true
        } label: {
          HStack(spacing: DS.Spacing.xs) {
            OverlappingAvatars(
              userIds: item.assigneeUserIds,
              users: userLookup,
              maxVisible: 3,
              size: .small
            )
            Image(systemName: "chevron.right")
              .font(DS.Typography.caption)
              .foregroundColor(DS.Colors.Text.tertiary)
          }
        }
        .buttonStyle(.plain)
      }

      // Quick assign/unassign button
      HStack {
        Spacer()
        Button {
          if isAssignedToMe {
            // Unassign me
            var newIds = item.assigneeUserIds
            newIds.removeAll { $0 == currentUserId }
            onAssigneesChanged?(newIds)
          } else {
            // Assign me
            var newIds = item.assigneeUserIds
            newIds.append(currentUserId)
            onAssigneesChanged?(newIds)
          }
        } label: {
          HStack(spacing: DS.Spacing.xs) {
            Image(systemName: isAssignedToMe ? "person.fill.badge.minus" : "person.fill.badge.plus")
            Text(isAssignedToMe ? "Unassign Me" : "Assign to Me")
          }
          .font(DS.Typography.caption)
          .foregroundColor(isAssignedToMe ? DS.Colors.Text.secondary : DS.Colors.accent)
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var assigneePickerSheet: some View {
    NavigationStack {
      MultiUserPicker(
        selectedUserIds: $selectedAssigneeIds,
        availableUsers: availableUsers,
        currentUserId: currentUserId
      )
      .navigationTitle("Assign Users")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              showAssigneePicker = false
            }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") {
              showAssigneePicker = false
              onAssigneesChanged?(Array(selectedAssigneeIds))
            }
          }
        }
    }
    #if os(macOS)
    .frame(minWidth: 300, minHeight: 400)
    #endif
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
  let users: [UUID: User] = {
    var dict = [UUID: User]()
    let ids = [UUID(), UUID(), UUID()]
    let names = ["Alice Smith", "Bob Jones", "Carol White"]
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
  let currentUserId = userIds[0]

  let sampleTask = TaskItem(
    title: "Review quarterly report",
    taskDescription: "Go through the Q4 numbers and prepare a summary for the board meeting.",
    dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
    declaredBy: userIds[1],
    assigneeUserIds: Array(userIds.prefix(2))
  )

  NavigationStack {
    WorkItemDetailView(
      item: .task(sampleTask),
      userLookup: users,
      currentUserId: currentUserId,
      availableUsers: Array(users.values),
      onComplete: { },
      onAssigneesChanged: { _ in },
      onAddNote: { _ in }
    )
  }
  .environmentObject(LensState())
}
