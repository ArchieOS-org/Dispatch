//
//  WorkItemDetailView.swift
//  Dispatch
//
//  WorkItem Component - Full detail view
//  Refactored for Layout Unification (StandardScreen)
//

import Supabase
import SwiftData
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
  var onDeleteItem: (() -> Void)?

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
    #if os(macOS)
    .onDeleteCommand {
      if onDeleteItem != nil {
        showDeleteItemAlert = true
      }
    }
    .alert("Delete \(item.isTask ? "Task" : "Activity")?", isPresented: $showDeleteItemAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Delete", role: .destructive) {
        onDeleteItem?()
      }
    } message: {
      Text("This \(item.isTask ? "task" : "activity") will be marked as deleted.")
    }
    #endif
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

  #if os(macOS)
  /// State for keyboard-triggered deletion
  @State private var showDeleteItemAlert = false
  #endif

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

      // History Section
      Color.clear.frame(height: DS.Spacing.lg)
      HistorySection(
        entityType: item.isTask ? .task : .activity,
        entityId: item.id,
        currentUserId: currentUserId,
        userLookup: { userLookup[$0] },
        supabase: supabase,
        onRestore: nil
      )
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

#Preview("Task Detail View") {
  PreviewShell(
    setup: { context in
      PreviewDataFactory.seed(context)
    }
  ) { context in
    let users = (try? context.fetch(FetchDescriptor<User>())) ?? []
    let usersById = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })

    let sampleTask = TaskItem(
      title: "Review quarterly report",
      taskDescription: "Go through the Q4 numbers and prepare a summary for the board meeting.",
      dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
      declaredBy: PreviewDataFactory.bobID,
      assigneeUserIds: [PreviewDataFactory.aliceID, PreviewDataFactory.bobID]
    )

    WorkItemDetailView(
      item: .task(sampleTask),
      userLookup: usersById,
      currentUserId: PreviewDataFactory.aliceID,
      availableUsers: users,
      onComplete: { },
      onAssigneesChanged: { _ in },
      onAddNote: { _ in }
    )
  }
}

#Preview("Activity Detail View") {
  PreviewShell(
    setup: { context in
      PreviewDataFactory.seed(context)
    }
  ) { context in
    let users = (try? context.fetch(FetchDescriptor<User>())) ?? []
    let usersById = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })

    let sampleActivity = Activity(
      title: "Client follow-up call",
      activityDescription: "Call to discuss the offer and next steps in the process.",
      status: .open,
      declaredBy: PreviewDataFactory.aliceID,
      listingId: PreviewDataFactory.listingID,
      assigneeUserIds: [PreviewDataFactory.bobID]
    )

    WorkItemDetailView(
      item: .activity(sampleActivity),
      userLookup: usersById,
      currentUserId: PreviewDataFactory.aliceID,
      availableUsers: users,
      onComplete: { },
      onAssigneesChanged: { _ in },
      onAddNote: { _ in }
    )
  }
}

#Preview("Task with Notes") {
  PreviewShell(
    setup: { context in
      PreviewDataFactory.seed(context)

      // Add a task with notes during setup
      let sampleTask = TaskItem(
        title: "Update lockbox code",
        taskDescription: "Change the lockbox code for the showing this weekend.",
        status: .open,
        declaredBy: PreviewDataFactory.aliceID,
        listingId: PreviewDataFactory.listingID
      )
      sampleTask.syncState = .synced
      context.insert(sampleTask)

      // Add sample notes
      let note1 = Note(
        content: "New code should be 4567",
        createdBy: PreviewDataFactory.aliceID,
        parentType: .task,
        parentId: sampleTask.id
      )
      note1.createdAt = Date().addingTimeInterval(-3600)
      sampleTask.notes.append(note1)

      let note2 = Note(
        content: "Updated and confirmed with owner",
        createdBy: PreviewDataFactory.bobID,
        parentType: .task,
        parentId: sampleTask.id
      )
      sampleTask.notes.append(note2)
    }
  ) { context in
    let users = (try? context.fetch(FetchDescriptor<User>())) ?? []
    let usersById = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })

    let taskDescriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == "Update lockbox code" })
    if let task = try? context.fetch(taskDescriptor).first {
      WorkItemDetailView(
        item: .task(task),
        userLookup: usersById,
        currentUserId: PreviewDataFactory.aliceID,
        availableUsers: users,
        onComplete: { },
        onAssigneesChanged: { _ in },
        onAddNote: { _ in }
      )
    } else {
      Text("Missing preview data")
    }
  }
}
