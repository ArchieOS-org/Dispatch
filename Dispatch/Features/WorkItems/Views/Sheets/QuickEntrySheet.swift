//
//  QuickEntrySheet.swift
//  Dispatch
//
//  Jobs-Standard sheet for quickly creating Tasks or Activities.
//

import SwiftData
import SwiftUI

/// Jobs-Standard sheet for quickly creating Tasks or Activities.
/// Features:
/// - Unified type picker (Task/Activity) with segmented control
/// - Context-aware fields (activity type shown only for activities)
/// - Optional listing association
/// - Priority selection with visual indicators
/// - Callback-based save for parent sync control
struct QuickEntrySheet: View {

  // MARK: Lifecycle

  init(
    defaultItemType: QuickEntryItemType = .task,
    currentUserId: UUID,
    listings: [Listing] = [],
    onSave: @escaping () -> Void
  ) {
    self.defaultItemType = defaultItemType
    self.currentUserId = currentUserId
    self.listings = listings
    self.onSave = onSave
    _itemType = State(initialValue: defaultItemType)
  }

  // MARK: Internal

  /// The default item type when the sheet opens
  let defaultItemType: QuickEntryItemType

  /// Current user ID for declaredBy field
  let currentUserId: UUID

  /// Available listings for selection (passed from parent to avoid @Query in sheet)
  let listings: [Listing]

  /// Callback when save completes (for triggering sync)
  var onSave: () -> Void

  var body: some View {
    NavigationStack {
      Form {
        typeSection
        titleSection
        if itemType == .activity {
          activityTypeSection
        }
        if !listings.isEmpty {
          listingSection
        }
        prioritySection
      }
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
    }
    #if os(iOS)
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
    #endif
  }

  // MARK: Private

  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  @State private var itemType: QuickEntryItemType
  @State private var title = ""
  @State private var selectedListing: Listing?
  @State private var priority = Priority.medium
  @State private var activityType = ActivityType.other

  private var canSave: Bool {
    !title.trimmingCharacters(in: .whitespaces).isEmpty
  }

  private var titlePlaceholder: String {
    switch itemType {
    case .task: "What needs to be done?"
    case .activity: "Activity title"
    }
  }

  // MARK: - Form Sections

  private var typeSection: some View {
    Section {
      Picker("Type", selection: $itemType) {
        ForEach(QuickEntryItemType.allCases) { type in
          Label(type.displayName, systemImage: type.icon)
            .tag(type)
        }
      }
      .pickerStyle(.segmented)
    }
  }

  private var titleSection: some View {
    Section {
      TextField(titlePlaceholder, text: $title)
    } header: {
      Text("Title")
    } footer: {
      if title.trimmingCharacters(in: .whitespaces).isEmpty {
        Text("Required")
          .foregroundColor(DS.Colors.destructive)
      }
    }
  }

  private var activityTypeSection: some View {
    Section("Activity Type") {
      Picker("Activity Type", selection: $activityType) {
        ForEach(ActivityType.allCases, id: \.self) { type in
          Text(type.displayName)
            .tag(type)
        }
      }
      .pickerStyle(.menu)
    }
  }

  private var listingSection: some View {
    Section("Listing") {
      Picker("Listing", selection: $selectedListing) {
        Text("None").tag(nil as Listing?)
        ForEach(listings) { listing in
          Text(listing.address).tag(listing as Listing?)
        }
      }
      .pickerStyle(.menu)
    }
  }

  private var prioritySection: some View {
    Section("Priority") {
      Picker("Priority", selection: $priority) {
        ForEach(Priority.allCases, id: \.self) { priority in
          HStack {
            PriorityDot(priority: priority)
            Text(priority.rawValue.capitalized)
          }
          .tag(priority)
        }
      }
      .pickerStyle(.menu)
    }
  }

  // MARK: - Actions

  private func saveAndDismiss() {
    let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
    guard !trimmedTitle.isEmpty else { return }

    switch itemType {
    case .task:
      let task = TaskItem(
        title: trimmedTitle,
        priority: priority,
        declaredBy: currentUserId,
        listingId: selectedListing?.id
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
        type: activityType,
        priority: priority,
        declaredBy: currentUserId,
        listingId: selectedListing?.id
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

#Preview("Quick Entry · Task") {
  PreviewShell { context in
    let listings = (try? context.fetch(FetchDescriptor<Listing>())) ?? []

    QuickEntrySheet(
      defaultItemType: .task,
      currentUserId: PreviewDataFactory.aliceID,
      listings: listings,
      onSave: { }
    )
  }
}

#Preview("Quick Entry · Activity") {
  PreviewShell { context in
    let listings = (try? context.fetch(FetchDescriptor<Listing>())) ?? []

    QuickEntrySheet(
      defaultItemType: .activity,
      currentUserId: PreviewDataFactory.aliceID,
      listings: listings,
      onSave: { }
    )
  }
}

#Preview("Quick Entry · No Listings") {
  QuickEntrySheet(
    defaultItemType: .task,
    currentUserId: UUID(),
    listings: [],
    onSave: { }
  )
}

#endif
