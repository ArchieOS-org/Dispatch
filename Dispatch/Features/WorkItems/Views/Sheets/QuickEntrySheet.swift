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
    preselectedListingId: UUID? = nil,
    onSave: @escaping () -> Void
  ) {
    self.defaultItemType = defaultItemType
    self.currentUserId = currentUserId
    self.listings = listings
    self.availableUsers = availableUsers
    self.preselectedListingId = preselectedListingId
    self.onSave = onSave
    _itemType = State(initialValue: defaultItemType)
    // Start with no assignee - user can select themselves from the top of the list
    _selectedAssigneeIds = State(initialValue: [])
    // Initialize selectedListing synchronously in init (not .task) so it's set on first render
    // This fixes macOS pre-selection which requires the value before the view appears
    if let listingId = preselectedListingId {
      _selectedListing = State(initialValue: listings.first { $0.id == listingId })
    } else {
      _selectedListing = State(initialValue: nil)
    }
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

  /// Optional listing ID to pre-select when opening from a listing detail view
  let preselectedListingId: UUID?

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
        .sheet(isPresented: $showListingPicker) {
          listingPickerSheet
        }
    }
    #if os(iOS)
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    #endif
    // NOTE: Listing pre-selection moved to init() for synchronous initialization
    // Using .task here caused macOS pre-selection to fail (async runs after first render)
  }

  // MARK: Private

  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  @State private var itemType: QuickEntryItemType
  @State private var title = ""
  @State private var itemDescription = ""
  @State private var selectedListing: Listing? // Initialized in init() for synchronous pre-selection
  @State private var hasDueDate = false
  @State private var dueDate = Date()
  @State private var selectedAssigneeIds: Set<UUID> = []
  @State private var showAssigneePicker = false
  @State private var showListingPicker = false

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

      LabeledContent("Description") {
        TextField("Description", text: $itemDescription, prompt: Text("Add details (optional)"))
          .labelsHidden()
          .textFieldStyle(.roundedBorder)
      }

      if !listings.isEmpty {
        LabeledContent("Listing") {
          Button {
            showListingPicker = true
          } label: {
            HStack {
              if let listing = selectedListing {
                Text(listing.address.titleCased())
                  .foregroundColor(DS.Colors.Text.primary)
                  .lineLimit(1)
              } else {
                Text("None")
                  .foregroundColor(DS.Colors.Text.tertiary)
              }
              Spacer()
              Image(systemName: DS.Icons.Navigation.forward)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.Text.tertiary)
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .frame(minHeight: DS.Spacing.minTouchTarget)
          .accessibilityLabel("Listing")
          .accessibilityValue(selectedListing?.address ?? "None")
          .accessibilityHint("Double tap to select a listing")
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
            Image(systemName: DS.Icons.Navigation.forward)
              .font(DS.Typography.caption)
              .foregroundColor(DS.Colors.Text.tertiary)
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: DS.Spacing.minTouchTarget)
        .accessibilityLabel("Assign to")
        .accessibilityValue(selectedAssigneeIds.isEmpty ? "No one assigned" : "\(selectedAssigneeIds.count) people")
        .accessibilityHint("Double tap to select assignees")
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
        descriptionField
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

  private var descriptionField: some View {
    TextField("Description", text: $itemDescription, prompt: Text("Add details (optional)"))
  }

  private var listingPicker: some View {
    Button {
      showListingPicker = true
    } label: {
      HStack {
        Text("Listing")
          .foregroundColor(DS.Colors.Text.primary)
        Spacer()
        if let listing = selectedListing {
          Text(listing.address.titleCased())
            .foregroundColor(DS.Colors.Text.secondary)
            .lineLimit(1)
        } else {
          Text("None")
            .foregroundColor(DS.Colors.Text.tertiary)
        }
        Image(systemName: DS.Icons.Navigation.forward)
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.tertiary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .frame(minHeight: DS.Spacing.minTouchTarget)
    .accessibilityLabel("Listing")
    .accessibilityValue(selectedListing?.address ?? "None")
    .accessibilityHint("Double tap to select a listing")
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
        Image(systemName: DS.Icons.Navigation.forward)
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.tertiary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .frame(minHeight: DS.Spacing.minTouchTarget)
    .accessibilityLabel("Assign to")
    .accessibilityValue(selectedAssigneeIds.isEmpty ? "No one" : "\(selectedAssigneeIds.count) people")
    .accessibilityHint("Double tap to select assignees")
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

  private var listingPickerSheet: some View {
    NavigationStack {
      List {
        // "None" option
        Button {
          selectedListing = nil
          showListingPicker = false
        } label: {
          HStack {
            Text("None")
              .foregroundColor(DS.Colors.Text.primary)
            Spacer()
            if selectedListing == nil {
              Image(systemName: "checkmark")
                .foregroundColor(DS.Colors.accent)
            }
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: DS.Spacing.minTouchTarget)

        // Listing options
        ForEach(listings) { listing in
          Button {
            selectedListing = listing
            showListingPicker = false
          } label: {
            HStack {
              VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(listing.address.titleCased())
                  .font(DS.Typography.headline)
                  .foregroundColor(DS.Colors.Text.primary)
                  .lineLimit(1)
                if !listing.city.isEmpty {
                  Text(listing.city.titleCased())
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.Text.secondary)
                }
              }
              Spacer()
              if selectedListing?.id == listing.id {
                Image(systemName: "checkmark")
                  .foregroundColor(DS.Colors.accent)
              }
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .frame(minHeight: DS.Spacing.minTouchTarget)
        }
      }
      .navigationTitle("Select Listing")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              showListingPicker = false
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
    let trimmedDescription = itemDescription.trimmingCharacters(in: .whitespaces)

    switch itemType {
    case .task:
      let task = TaskItem(
        title: trimmedTitle,
        taskDescription: trimmedDescription,
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
        activityDescription: trimmedDescription,
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
