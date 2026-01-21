//
//  QuickEntrySheet.swift
//  Dispatch
//
//  Jobs-Standard sheet for quickly creating Tasks or Activities.
//

import SwiftData
import SwiftUI

// MARK: - QuickEntrySheet

/// Jobs-Standard sheet for quickly creating Tasks or Activities.
/// Features:
/// - Unified type picker (Task/Activity) with segmented control
/// - Optional listing association
/// - Multi-assignee selection
/// - Due date picker
/// - Callback-based save for parent sync control
struct QuickEntrySheet: View {

  // MARK: Lifecycle

  init(
    defaultItemType: QuickEntryItemType = .task,
    currentUserId: UUID,
    listings: [Listing] = [],
    availableUsers: [User] = [],
    onSave: @escaping () -> Void
  ) {
    self.defaultItemType = defaultItemType
    self.currentUserId = currentUserId
    self.listings = listings
    self.availableUsers = availableUsers
    self.onSave = onSave
    _itemType = State(initialValue: defaultItemType)
    // Start with no assignee - user can tap "Assign to me" for quick self-assignment
    _selectedAssigneeIds = State(initialValue: [])
  }

  // MARK: Internal

  /// The default item type when the sheet opens
  let defaultItemType: QuickEntryItemType

  /// Current user ID for declaredBy field
  let currentUserId: UUID

  /// Available listings for selection (passed from parent to avoid @Query in sheet)
  let listings: [Listing]

  /// Available users for assignee selection
  let availableUsers: [User]

  /// Callback when save completes (for triggering sync)
  var onSave: () -> Void

  var body: some View {
    NavigationStack {
      formContent
        .navigationTitle("Quick Add")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              dismiss()
            }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Add") {
              saveAndDismiss()
            }
            .disabled(!canSave)
          }
        }
        .sheet(isPresented: $showAssigneePicker) {
          assigneePickerSheet
        }
    }
    #if os(iOS)
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    #endif
  }

  // MARK: Private

  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  @State private var itemType: QuickEntryItemType
  @State private var title = ""
  @State private var selectedListing: Listing?
  @State private var hasDueDate = false
  @State private var dueDate = Date()
  @State private var selectedAssigneeIds: Set<UUID> = []
  @State private var showAssigneePicker = false

  private var canSave: Bool {
    !title.trimmingCharacters(in: .whitespaces).isEmpty
  }

  private var titlePlaceholder: String {
    switch itemType {
    case .task: "What needs to be done?"
    case .activity: "Activity title"
    }
  }

  private var userLookup: [UUID: User] {
    Dictionary(uniqueKeysWithValues: availableUsers.map { ($0.id, $0) })
  }

  // MARK: - Platform Form Content

  @ViewBuilder
  private var formContent: some View {
    #if os(macOS)
    macOSForm
    #else
    iOSForm
    #endif
  }

  #if os(macOS)
  private var macOSForm: some View {
    VStack(alignment: .leading, spacing: 16) {
      LabeledContent("Type") {
        Picker("Type", selection: $itemType) {
          ForEach(QuickEntryItemType.allCases) { type in
            Label(type.displayName, systemImage: type.icon)
              .tag(type)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }

      LabeledContent("Title") {
        TextField("Title", text: $title, prompt: Text(titlePlaceholder))
          .labelsHidden()
          .textFieldStyle(.roundedBorder)
      }

      if !listings.isEmpty {
        LabeledContent("Listing") {
          Picker("Listing", selection: $selectedListing) {
            Text("None").tag(nil as Listing?)
            ForEach(listings) { listing in
              Text(listing.address.titleCased()).tag(listing as Listing?)
            }
          }
          .labelsHidden()
        }
      }

      VStack(alignment: .leading, spacing: 8) {
        LabeledContent("Due Date") {
          Toggle("", isOn: $hasDueDate)
            .labelsHidden()
        }
        if hasDueDate {
          DatePicker("", selection: $dueDate, displayedComponents: [.date])
            .datePickerStyle(.graphical)
            .labelsHidden()
        }
      }

      LabeledContent("Assign to") {
        Button {
          showAssigneePicker = true
        } label: {
          HStack {
            if selectedAssigneeIds.isEmpty {
              Text("No one assigned")
                .foregroundColor(DS.Colors.Text.tertiary)
            } else {
              let userLookup = Dictionary(uniqueKeysWithValues: availableUsers.map { ($0.id, $0) })
              OverlappingAvatars(
                userIds: Array(selectedAssigneeIds),
                users: userLookup,
                maxVisible: 3,
                size: .small
              )
            }
            Spacer()
            Image(systemName: "chevron.right")
              .font(DS.Typography.caption)
              .foregroundColor(DS.Colors.Text.tertiary)
          }
        }
        .buttonStyle(.plain)
      }
    }
    .padding()
  }
  #endif

  private var iOSForm: some View {
    Form {
      Section {
        typePicker
        titleField
        if !listings.isEmpty {
          listingPicker
        }
        dueDateRow
        assigneesRow
      }
    }
  }

  // MARK: - Form Rows

  private var typePicker: some View {
    Picker("Type", selection: $itemType) {
      ForEach(QuickEntryItemType.allCases) { type in
        Label(type.displayName, systemImage: type.icon)
          .tag(type)
      }
    }
    .pickerStyle(.segmented)
  }

  private var titleField: some View {
    TextField("Title", text: $title, prompt: Text(titlePlaceholder))
  }

  private var listingPicker: some View {
    Picker("Listing", selection: $selectedListing) {
      Text("None").tag(nil as Listing?)
      ForEach(listings) { listing in
        Text(listing.address.titleCased()).tag(listing as Listing?)
      }
    }
    .pickerStyle(.menu)
  }

  private var dueDateRow: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("Due Date")
        Spacer()
        Toggle("", isOn: $hasDueDate)
          .labelsHidden()
      }
      if hasDueDate {
        DatePicker("", selection: $dueDate, displayedComponents: [.date])
          .datePickerStyle(.graphical)
          .labelsHidden()
      }
    }
  }

  private var assigneesRow: some View {
    Button {
      showAssigneePicker = true
    } label: {
      HStack {
        Text("Assign to")
          .foregroundColor(DS.Colors.Text.primary)
        Spacer()
        if selectedAssigneeIds.isEmpty {
          Text("No one")
            .foregroundColor(DS.Colors.Text.tertiary)
        } else {
          OverlappingAvatars(
            userIds: Array(selectedAssigneeIds),
            users: userLookup,
            maxVisible: 3,
            size: .small
          )
        }
        Image(systemName: "chevron.right")
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.tertiary)
      }
    }
    .buttonStyle(.plain)
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
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") {
              showAssigneePicker = false
            }
          }
        }
    }
    #if os(macOS)
    .frame(minWidth: 300, minHeight: 400)
    #endif
  }

  private func saveAndDismiss() {
    let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
    guard !trimmedTitle.isEmpty else { return }

    let effectiveDueDate = hasDueDate ? dueDate : nil

    switch itemType {
    case .task:
      let task = TaskItem(
        title: trimmedTitle,
        dueDate: effectiveDueDate,
        declaredBy: currentUserId,
        listingId: selectedListing?.id,
        assigneeUserIds: Array(selectedAssigneeIds)
      )
      // IMPORTANT: Insert into context BEFORE setting up relationships
      // SwiftData requires models to be in context before relationship manipulation
      modelContext.insert(task)

      // Now safe to set up relationships
      if let listing = selectedListing {
        task.listing = listing
        listing.tasks.append(task)
      }

    case .activity:
      let activity = Activity(
        title: trimmedTitle,
        dueDate: effectiveDueDate,
        declaredBy: currentUserId,
        listingId: selectedListing?.id,
        assigneeUserIds: Array(selectedAssigneeIds)
      )
      // IMPORTANT: Insert into context BEFORE setting up relationships
      // SwiftData requires models to be in context before relationship manipulation
      modelContext.insert(activity)

      // Now safe to set up relationships
      if let listing = selectedListing {
        activity.listing = listing
        listing.activities.append(activity)
      }
    }

    onSave()
    dismiss()
  }
}

// MARK: - Preview

#if DEBUG

#Preview("Quick Entry - Task") {
  PreviewShell { context in
    let listings = (try? context.fetch(FetchDescriptor<Listing>())) ?? []
    let users = (try? context.fetch(FetchDescriptor<User>())) ?? []

    QuickEntrySheet(
      defaultItemType: .task,
      currentUserId: PreviewDataFactory.aliceID,
      listings: listings,
      availableUsers: users,
      onSave: { }
    )
  }
}

#Preview("Quick Entry - Activity") {
  PreviewShell { context in
    let listings = (try? context.fetch(FetchDescriptor<Listing>())) ?? []
    let users = (try? context.fetch(FetchDescriptor<User>())) ?? []

    QuickEntrySheet(
      defaultItemType: .activity,
      currentUserId: PreviewDataFactory.aliceID,
      listings: listings,
      availableUsers: users,
      onSave: { }
    )
  }
}

#Preview("Quick Entry - No Listings") {
  QuickEntrySheet(
    defaultItemType: .task,
    currentUserId: UUID(),
    listings: [],
    availableUsers: [],
    onSave: { }
  )
}

#endif
