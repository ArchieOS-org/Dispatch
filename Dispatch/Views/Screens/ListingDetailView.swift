//
//  ListingDetailView.swift
//  Dispatch
//
//  Full detail view for a Listing with tabbed navigation
//  Created by Claude on 2025-12-06.
//

import SwiftUI
import SwiftData

/// Full detail view for a Listing.
/// Features:
/// - Header with address, owner, and status
/// - Segmented tabs for Tasks, Activities, and Notes
/// - CRUD operations for listing-level notes
/// - Navigation to task/activity details
struct ListingDetailView: View {
    let listing: Listing
    let userLookup: (UUID) -> User?

    @EnvironmentObject private var syncManager: SyncManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedTab = 0

    // Note management
    @State private var noteText = ""
    @State private var showNoteInput = false
    @State private var showDeleteNoteAlert = false
    @State private var noteToDelete: Note?

    // Delete listing
    @State private var showDeleteListingAlert = false

    // MARK: - Computed Properties

    private var currentUserId: UUID {
        syncManager.currentUserID ?? UUID()
    }

    private var owner: User? {
        userLookup(listing.ownedBy)
    }

    private var assignedStaff: User? {
        guard let staffId = listing.assignedStaff else { return nil }
        return userLookup(staffId)
    }

    private var activeTasks: [TaskItem] {
        listing.tasks.filter { $0.status != .deleted }
    }

    private var activeActivities: [Activity] {
        listing.activities.filter { $0.status != .deleted }
    }

    private var statusColor: Color {
        switch listing.status {
        case .draft: return DS.Colors.Text.tertiary
        case .active: return DS.Colors.success
        case .pending: return DS.Colors.warning
        case .closed: return DS.Colors.info
        case .deleted: return DS.Colors.Text.disabled
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection

                // Tab Picker
                Picker("Content", selection: $selectedTab) {
                    Text("Tasks (\(activeTasks.count))").tag(0)
                    Text("Activities (\(activeActivities.count))").tag(1)
                    Text("Notes (\(listing.notes.count))").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DS.Spacing.md)

                // Tab Content
                switch selectedTab {
                case 0:
                    tasksTab
                case 1:
                    activitiesTab
                case 2:
                    notesTab
                default:
                    EmptyView()
                }

                bottomActions
            }
            .padding(.vertical, DS.Spacing.md)
        }
        .background(DS.Colors.Background.primary)
        .navigationTitle("Listing")
        .navigationBarTitleDisplayMode(.inline)
        // MARK: - Alerts
        .alert("Delete Listing?", isPresented: $showDeleteListingAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteListing()
            }
        } message: {
            Text("This listing will be marked as deleted. Associated tasks and activities will remain.")
        }
        .alert("Delete Note?", isPresented: $showDeleteNoteAlert) {
            Button("Cancel", role: .cancel) {
                noteToDelete = nil
            }
            Button("Delete", role: .destructive) {
                confirmDeleteNote()
            }
        } message: {
            Text("This note will be permanently deleted.")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Address
            Text(listing.address)
                .font(.title.bold())
                .foregroundColor(DS.Colors.Text.primary)

            // Location
            if !listing.city.isEmpty {
                Text("\(listing.city), \(listing.province) \(listing.postalCode)")
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.Text.secondary)
            }

            // Owner and Staff badges
            HStack(spacing: DS.Spacing.md) {
                if let owner = owner {
                    HStack(spacing: DS.Spacing.xs) {
                        UserAvatar(user: owner, size: .small)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Owner")
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.Text.tertiary)
                            Text(owner.name)
                                .font(DS.Typography.bodySecondary)
                                .foregroundColor(DS.Colors.Text.primary)
                        }
                    }
                }

                if let staff = assignedStaff {
                    HStack(spacing: DS.Spacing.xs) {
                        UserAvatar(user: staff, size: .small)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Assigned")
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.Text.tertiary)
                            Text(staff.name)
                                .font(DS.Typography.bodySecondary)
                                .foregroundColor(DS.Colors.Text.primary)
                        }
                    }
                }
            }

            // Status and Edit row
            HStack {
                // Status badge
                Text(listing.status.rawValue.capitalized)
                    .font(DS.Typography.caption)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(statusColor.opacity(0.15))
                    .cornerRadius(DS.Spacing.radiusSmall)

                // Listing type badge
                Text(listing.listingType.rawValue.capitalized)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.Text.secondary)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(DS.Colors.Background.secondary)
                    .cornerRadius(DS.Spacing.radiusSmall)

                Spacer()

                // Edit button (placeholder)
                Button(action: { /* Phase 4: Edit listing */ }) {
                    Image(systemName: DS.Icons.Action.edit)
                        .foregroundColor(DS.Colors.accent)
                }
            }

            // Price (if available)
            if let price = listing.price {
                Text("$\(NSDecimalNumber(decimal: price).intValue.formatted())")
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.success)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.Background.card)
        .cornerRadius(DS.Spacing.radiusCard)
        .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - Tasks Tab

    private var tasksTab: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if activeTasks.isEmpty {
                emptyStateView(
                    icon: DS.Icons.Entity.task,
                    title: "No Tasks",
                    message: "Tasks for this listing will appear here"
                )
            } else {
                ForEach(activeTasks) { task in
                    NavigationLink(value: WorkItemRef.task(task)) {
                        WorkItemRow(
                            item: .task(task),
                            claimedByUser: task.claimedBy.flatMap { userLookup($0) }
                        )
                    }
                    .buttonStyle(.plain)

                    if task.id != activeTasks.last?.id {
                        Divider()
                            .padding(.horizontal, DS.Spacing.md)
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.Background.card)
        .cornerRadius(DS.Spacing.radiusCard)
        .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - Activities Tab

    private var activitiesTab: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if activeActivities.isEmpty {
                emptyStateView(
                    icon: DS.Icons.Entity.activity,
                    title: "No Activities",
                    message: "Activities for this listing will appear here"
                )
            } else {
                ForEach(activeActivities) { activity in
                    NavigationLink(value: WorkItemRef.activity(activity)) {
                        WorkItemRow(
                            item: .activity(activity),
                            claimedByUser: activity.claimedBy.flatMap { userLookup($0) }
                        )
                    }
                    .buttonStyle(.plain)

                    if activity.id != activeActivities.last?.id {
                        Divider()
                            .padding(.horizontal, DS.Spacing.md)
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.Background.card)
        .cornerRadius(DS.Spacing.radiusCard)
        .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - Notes Tab

    private var notesTab: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Notes")
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.Text.primary)
                Spacer()
                Button(action: { showNoteInput.toggle() }) {
                    Image(systemName: showNoteInput ? DS.Icons.Action.cancel : DS.Icons.Action.add)
                        .font(.system(size: 16))
                        .foregroundColor(DS.Colors.accent)
                }
            }

            if showNoteInput {
                NoteInputArea(
                    text: $noteText,
                    placeholder: "Add a note to this listing...",
                    onSave: {
                        addNote(content: noteText)
                        noteText = ""
                        showNoteInput = false
                    },
                    onCancel: {
                        noteText = ""
                        showNoteInput = false
                    }
                )
            }

            if listing.notes.isEmpty && !showNoteInput {
                NoteStack.emptyState
            } else if !listing.notes.isEmpty {
                NoteStack(
                    notes: listing.notes,
                    userLookup: userLookup,
                    onEdit: nil, // Phase 4: Edit note
                    onDelete: { note in
                        noteToDelete = note
                        showDeleteNoteAlert = true
                    }
                )
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.Background.card)
        .cornerRadius(DS.Spacing.radiusCard)
        .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        HStack(spacing: DS.Spacing.md) {
            Button(action: { /* Phase 4: Edit listing sheet */ }) {
                HStack {
                    Image(systemName: DS.Icons.Action.edit)
                    Text("Edit Listing")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive, action: { showDeleteListingAlert = true }) {
                HStack {
                    Image(systemName: DS.Icons.Action.delete)
                    Text("Delete")
                }
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.md)
    }

    // MARK: - Actions

    private func addNote(content: String) {
        let note = Note(
            content: content,
            createdBy: currentUserId,
            parentType: .listing,
            parentId: listing.id
        )
        listing.notes.append(note)
        listing.updatedAt = Date()
        syncManager.requestSync()
    }

    private func confirmDeleteNote() {
        guard let note = noteToDelete else { return }
        listing.notes.removeAll { $0.id == note.id }
        modelContext.delete(note)
        listing.updatedAt = Date()
        noteToDelete = nil
        syncManager.requestSync()
    }

    private func deleteListing() {
        listing.status = .deleted
        listing.deletedAt = Date()
        listing.updatedAt = Date()
        syncManager.requestSync()
        dismiss()
    }

    // MARK: - Helpers

    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(DS.Colors.Text.tertiary)
            Text(title)
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.Text.secondary)
            Text(message)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.Text.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }
}

// MARK: - Preview

#Preview("Listing Detail View") {
    let listing = Listing(
        address: "123 Main Street",
        city: "Toronto",
        province: "ON",
        postalCode: "M5V 1A1",
        price: 1250000,
        listingType: .sale,
        status: .active,
        ownedBy: UUID()
    )

    let user = User(name: "John Smith", email: "john@example.com", userType: .realtor)

    NavigationStack {
        ListingDetailView(listing: listing, userLookup: { _ in user })
    }
    .modelContainer(for: [Listing.self, User.self, TaskItem.self, Activity.self, Note.self], inMemory: true)
    .environmentObject(SyncManager.shared)
}
