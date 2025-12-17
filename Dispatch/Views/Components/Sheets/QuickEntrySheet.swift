//
//  QuickEntrySheet.swift
//  Dispatch
//
//  Universal quick entry sheet for creating Tasks and Activities
//

import SwiftUI
import SwiftData

/// A unified sheet for quickly creating Tasks or Activities.
///
/// Design decisions:
/// 1. Single sheet handles both item types (Task/Activity) with a type picker
/// 2. Type-specific fields (ActivityType) shown conditionally
/// 3. All common fields (title, listing, priority) shared
/// 4. Callback-based save to allow parent view to handle sync
/// 5. Listings passed as parameter to avoid @Query re-evaluation on keystrokes
///
/// Usage:
/// ```swift
/// .sheet(isPresented: $showQuickEntry) {
///     QuickEntrySheet(
///         defaultItemType: .task,
///         currentUserId: currentUserId,
///         listings: listings,
///         onSave: { syncManager.requestSync() }
///     )
/// }
/// ```
struct QuickEntrySheet: View {
    /// The default item type when the sheet opens
    let defaultItemType: QuickEntryItemType

    /// Current user ID for declaredBy field
    let currentUserId: UUID

    /// Available listings for selection (passed from parent to avoid @Query in sheet)
    let listings: [Listing]

    /// Callback when save completes (for triggering sync)
    var onSave: () -> Void

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Form State

    @State private var itemType: QuickEntryItemType
    @State private var title: String = ""
    @State private var selectedListing: Listing?
    @State private var priority: Priority = .medium
    @State private var activityType: ActivityType = .other

    // MARK: - Computed Properties

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Init

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
        self._itemType = State(initialValue: defaultItemType)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Type Selection
                Section {
                    Picker("Type", selection: $itemType) {
                        ForEach(QuickEntryItemType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Title (required)
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

                // Activity Type (only for activities)
                if itemType == .activity {
                    Section("Activity Type") {
                        Picker("Activity Type", selection: $activityType) {
                            ForEach(ActivityType.allCases, id: \.self) { type in
                                Text(activityTypeLabel(type))
                                    .tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                // Listing (optional)
                if !listings.isEmpty {
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

                // Priority
                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases, id: \.self) { priority in
                            HStack {
                                Circle()
                                    .fill(DS.Colors.PriorityColors.color(for: priority))
                                    .frame(width: DS.Spacing.priorityDotSize, height: DS.Spacing.priorityDotSize)
                                Text(priority.rawValue.capitalized)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(.menu)
                }
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

    // MARK: - Helpers

    private var titlePlaceholder: String {
        switch itemType {
        case .task: return "What needs to be done?"
        case .activity: return "Activity title"
        }
    }

    private func activityTypeLabel(_ type: ActivityType) -> String {
        switch type {
        case .call: return "Phone Call"
        case .email: return "Email"
        case .meeting: return "Meeting"
        case .showProperty: return "Show Property"
        case .followUp: return "Follow Up"
        case .other: return "Other"
        }
    }

    // MARK: - Save Logic

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

        // TODO: Show toast "Task added" / "Activity added"
        onSave()
        dismiss()
    }
}

// MARK: - Preview

#Preview("Quick Entry Sheet - Task") {
    QuickEntrySheet(
        defaultItemType: .task,
        currentUserId: UUID(),
        listings: [],
        onSave: { print("Saved!") }
    )
}

#Preview("Quick Entry Sheet - Activity") {
    QuickEntrySheet(
        defaultItemType: .activity,
        currentUserId: UUID(),
        listings: [],
        onSave: { print("Saved!") }
    )
}
