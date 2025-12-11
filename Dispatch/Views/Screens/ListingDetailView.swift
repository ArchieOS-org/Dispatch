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

    /// Sentinel UUID for unauthenticated state - stable across all accesses
    private static let unauthenticatedUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    private var currentUserId: UUID {
        syncManager.currentUserID ?? Self.unauthenticatedUserId
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
    @Previewable @State var syncManager = SyncManager.shared

    let container = try! ModelContainer(
        for: Listing.self, TaskItem.self, Activity.self, User.self, Note.self, Subtask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let context = container.mainContext

    // MARK: - Create Users

    let ownerUser = User(
        name: "Sarah Mitchell",
        email: "sarah@remax.ca",
        userType: .realtor
    )
    context.insert(ownerUser)

    let staffUser = User(
        name: "David Chen",
        email: "david@dispatch.ca",
        userType: .admin
    )
    context.insert(staffUser)

    let otherUser = User(
        name: "Emily Rodriguez",
        email: "emily@dispatch.ca",
        userType: .admin
    )
    context.insert(otherUser)

    syncManager.currentUserID = staffUser.id

    // MARK: - Create Listing

    let listing = Listing(
        address: "742 Evergreen Terrace",
        city: "Toronto",
        province: "ON",
        postalCode: "M5V 2K7",
        price: 1895000,
        mlsNumber: "W9876543",
        listingType: .sale,
        status: .active,
        ownedBy: ownerUser.id,
        assignedStaff: staffUser.id
    )
    context.insert(listing)

    // MARK: - Create Tasks for Listing

    // Overdue high-priority task
    let titleSearchTask = TaskItem(
        title: "Order title search",
        taskDescription: "Contact Stewart Title for property search - need full chain of ownership",
        dueDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
        priority: .high,
        status: .open,
        declaredBy: ownerUser.id,
        claimedBy: staffUser.id,
        listingId: listing.id
    )
    titleSearchTask.claimedAt = Calendar.current.date(byAdding: .day, value: -3, to: Date())
    context.insert(titleSearchTask)
    listing.tasks.append(titleSearchTask)

    // Add subtasks to title search
    let subtask1 = Subtask(
        title: "Contact Stewart Title",
        completed: true,
        parentType: .task,
        parentId: titleSearchTask.id
    )
    titleSearchTask.subtasks.append(subtask1)

    let subtask2 = Subtask(
        title: "Submit property details form",
        completed: true,
        parentType: .task,
        parentId: titleSearchTask.id
    )
    titleSearchTask.subtasks.append(subtask2)

    let subtask3 = Subtask(
        title: "Review search results",
        completed: false,
        parentType: .task,
        parentId: titleSearchTask.id
    )
    titleSearchTask.subtasks.append(subtask3)

    // Today task
    let inspectionTask = TaskItem(
        title: "Schedule home inspection",
        taskDescription: "Book with certified inspector - 3 hour window needed. Buyer prefers morning slots.",
        dueDate: Calendar.current.startOfDay(for: Date()),
        priority: .medium,
        status: .open,
        declaredBy: ownerUser.id,
        listingId: listing.id
    )
    context.insert(inspectionTask)
    listing.tasks.append(inspectionTask)

    // Add note to inspection task
    let inspectionNote = Note(
        content: "Inspector Mike (416-555-1234) confirmed availability for Thursday morning",
        createdBy: staffUser.id,
        parentType: .task,
        parentId: inspectionTask.id
    )
    inspectionTask.notes.append(inspectionNote)

    // Tomorrow task (claimed by other user)
    let appraisalTask = TaskItem(
        title: "Coordinate appraisal visit",
        taskDescription: "Bank appraiser needs access - coordinate with seller for best time",
        dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
        priority: .high,
        status: .open,
        declaredBy: ownerUser.id,
        claimedBy: otherUser.id,
        listingId: listing.id
    )
    appraisalTask.claimedAt = Date()
    context.insert(appraisalTask)
    listing.tasks.append(appraisalTask)

    // Completed task
    let photographyTask = TaskItem(
        title: "Professional photography session",
        taskDescription: "Schedule HDR photos and virtual tour - coordinate with staging",
        dueDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()),
        priority: .medium,
        status: .completed,
        declaredBy: ownerUser.id,
        claimedBy: staffUser.id,
        listingId: listing.id
    )
    photographyTask.completedAt = Calendar.current.date(byAdding: .day, value: -4, to: Date())
    context.insert(photographyTask)
    listing.tasks.append(photographyTask)

    // MARK: - Create Activities for Listing

    // Upcoming showing
    let showingActivity = Activity(
        title: "Property showing - Johnson family",
        activityDescription: "First-time buyers, pre-approved for $2M. Interested in the backyard and basement.",
        type: .showProperty,
        dueDate: Calendar.current.date(byAdding: .hour, value: 4, to: Date()),
        priority: .high,
        status: .open,
        declaredBy: ownerUser.id,
        claimedBy: staffUser.id,
        listingId: listing.id,
        duration: 3600
    )
    showingActivity.claimedAt = Date()
    context.insert(showingActivity)
    listing.activities.append(showingActivity)

    // Follow-up call
    let followUpActivity = Activity(
        title: "Follow up with mortgage broker",
        activityDescription: "Check on buyer's financing status - TD pre-approval letter pending",
        type: .call,
        dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
        priority: .medium,
        status: .open,
        declaredBy: staffUser.id,
        listingId: listing.id
    )
    context.insert(followUpActivity)
    listing.activities.append(followUpActivity)

    // Completed meeting
    let meetingActivity = Activity(
        title: "Seller consultation meeting",
        activityDescription: "Discussed pricing strategy and marketing plan",
        type: .meeting,
        dueDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
        priority: .medium,
        status: .completed,
        declaredBy: ownerUser.id,
        claimedBy: staffUser.id,
        listingId: listing.id,
        duration: 5400
    )
    meetingActivity.completedAt = Calendar.current.date(byAdding: .day, value: -3, to: Date())
    context.insert(meetingActivity)
    listing.activities.append(meetingActivity)

    // Add note to meeting activity
    let meetingNote = Note(
        content: "Seller agreed to price reduction if no offers within 2 weeks",
        createdBy: staffUser.id,
        parentType: .activity,
        parentId: meetingActivity.id
    )
    meetingActivity.notes.append(meetingNote)

    // MARK: - Create Listing-Level Notes

    let listingNote1 = Note(
        content: "Seller is motivated - relocating for work by end of month. Flexible on closing date.",
        createdBy: ownerUser.id,
        parentType: .listing,
        parentId: listing.id,
        createdAt: Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    )
    listing.notes.append(listingNote1)

    let listingNote2 = Note(
        content: "Property has new roof (2023) and updated HVAC. All permits on file.",
        createdBy: staffUser.id,
        parentType: .listing,
        parentId: listing.id,
        createdAt: Calendar.current.date(byAdding: .day, value: -5, to: Date())!
    )
    listing.notes.append(listingNote2)

    let listingNote3 = Note(
        content: "Neighbour mentioned interest - might make an offer if it stays on market",
        createdBy: otherUser.id,
        parentType: .listing,
        parentId: listing.id,
        createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    )
    listing.notes.append(listingNote3)

    // Build user lookup
    let userCache: [UUID: User] = [
        ownerUser.id: ownerUser,
        staffUser.id: staffUser,
        otherUser.id: otherUser
    ]

    return NavigationStack {
        ListingDetailView(listing: listing, userLookup: { userCache[$0] })
    }
    .modelContainer(container)
    .environmentObject(syncManager)
}

#Preview("Listing Detail - Empty") {
    @Previewable @State var syncManager = SyncManager.shared

    let container = try! ModelContainer(
        for: Listing.self, TaskItem.self, Activity.self, User.self, Note.self, Subtask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let context = container.mainContext

    let ownerUser = User(
        name: "Sarah Mitchell",
        email: "sarah@remax.ca",
        userType: .realtor
    )
    context.insert(ownerUser)

    syncManager.currentUserID = ownerUser.id

    // Empty listing with no tasks, activities, or notes
    let listing = Listing(
        address: "456 Oak Avenue",
        city: "Vancouver",
        province: "BC",
        postalCode: "V6B 1A1",
        price: 2450000,
        listingType: .sale,
        status: .draft,
        ownedBy: ownerUser.id
    )
    context.insert(listing)

    let userCache: [UUID: User] = [ownerUser.id: ownerUser]

    return NavigationStack {
        ListingDetailView(listing: listing, userLookup: { userCache[$0] })
    }
    .modelContainer(container)
    .environmentObject(syncManager)
}

#Preview("Listing Detail - Lease") {
    @Previewable @State var syncManager = SyncManager.shared

    let container = try! ModelContainer(
        for: Listing.self, TaskItem.self, Activity.self, User.self, Note.self, Subtask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let context = container.mainContext

    let ownerUser = User(
        name: "Michael Torres",
        email: "michael@royallepage.ca",
        userType: .realtor
    )
    context.insert(ownerUser)

    let staffUser = User(
        name: "Lisa Park",
        email: "lisa@dispatch.ca",
        userType: .admin
    )
    context.insert(staffUser)

    syncManager.currentUserID = staffUser.id

    let listing = Listing(
        address: "1200 Bay Street, Unit 2405",
        city: "Toronto",
        province: "ON",
        postalCode: "M5R 2A5",
        price: 3500,
        listingType: .lease,
        status: .pending,
        ownedBy: ownerUser.id,
        assignedStaff: staffUser.id
    )
    context.insert(listing)

    // Add a task
    let creditCheckTask = TaskItem(
        title: "Run tenant credit check",
        taskDescription: "Application received - run background and credit check",
        dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
        priority: .high,
        status: .open,
        declaredBy: ownerUser.id,
        claimedBy: staffUser.id,
        listingId: listing.id
    )
    context.insert(creditCheckTask)
    listing.tasks.append(creditCheckTask)

    // Add an activity
    let viewingActivity = Activity(
        title: "Virtual tour with applicant",
        activityDescription: "Zoom walkthrough of unit - applicant is relocating from Calgary",
        type: .meeting,
        dueDate: Date(),
        priority: .medium,
        status: .open,
        declaredBy: staffUser.id,
        listingId: listing.id
    )
    context.insert(viewingActivity)
    listing.activities.append(viewingActivity)

    // Add a note
    let leaseNote = Note(
        content: "Applicant works remotely for tech company - stable income verified",
        createdBy: staffUser.id,
        parentType: .listing,
        parentId: listing.id
    )
    listing.notes.append(leaseNote)

    let userCache: [UUID: User] = [
        ownerUser.id: ownerUser,
        staffUser.id: staffUser
    ]

    return NavigationStack {
        ListingDetailView(listing: listing, userLookup: { userCache[$0] })
    }
    .modelContainer(container)
    .environmentObject(syncManager)
}
