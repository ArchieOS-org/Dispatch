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
    @EnvironmentObject private var lensState: LensState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

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

    private var activeTasks: [TaskItem] {
        listing.tasks.filter { $0.status != .deleted }
    }

    private var activeActivities: [Activity] {
        listing.activities.filter { $0.status != .deleted }
    }

    /// Tasks filtered by current audience lens
    private var filteredTasks: [TaskItem] {
        activeTasks.filter { lensState.audience.matches(audiences: $0.audiences) }
    }

    /// Activities filtered by current audience lens
    private var filteredActivities: [Activity] {
        activeActivities.filter { lensState.audience.matches(audiences: $0.audiences) }
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

    private var listingActions: [OverflowMenu.Action] {
        [
            OverflowMenu.Action(id: "edit", title: "Edit Listing", icon: DS.Icons.Action.edit) {
                // Phase 4: Edit listing placeholder
            },
            OverflowMenu.Action(id: "delete", title: "Delete Listing", icon: DS.Icons.Action.delete, role: .destructive) {
                showDeleteListingAlert = true
            }
        ]
    }

    // MARK: - Body

    // MARK: - Body
    
    var body: some View {
        #if os(macOS)
        macOSLayout
        #else
        iOSLayout
        #endif
    }

    // MARK: - Platform Layouts

    @ViewBuilder
    private var macOSLayout: some View {
        StandardPageLayout {
            // Title Content
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                ProgressCircle(progress: listing.progress, size: 20)
                    .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 2 }
                
                Text(listing.address)
                    .font(.system(size: DS.Spacing.Layout.largeTitleSize, weight: .bold))
                    .foregroundColor(DS.Colors.Text.primary)
            }
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    metadataSection
                    
                    VStack(alignment: .leading, spacing: 0) {
                        notesHeader
                        Divider()
                            .padding(.top, DS.Spacing.sm)
                            .padding(.horizontal, DS.Spacing.md)
                        notesSection
                    }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        tasksHeader
                        Divider()
                            .padding(.top, DS.Spacing.sm)
                            .padding(.horizontal, DS.Spacing.md)
                        tasksSection
                    }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        activitiesHeader
                        Divider()
                            .padding(.top, DS.Spacing.sm)
                            .padding(.horizontal, DS.Spacing.md)
                        activitiesSection
                    }
                }
                .padding(.vertical, DS.Spacing.md)
            }
            .background(DS.Colors.Background.primary)
        } headerActions: {
            OverflowMenu(actions: listingActions)
        }
        // Alerts
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

    @ViewBuilder
    private var iOSLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection // Use original combined header for iOS
                
                VStack(alignment: .leading, spacing: 0) {
                    notesHeader
                    Divider()
                        .padding(.top, DS.Spacing.sm)
                        .padding(.horizontal, DS.Spacing.md)
                    notesSection
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    tasksHeader
                    Divider()
                        .padding(.top, DS.Spacing.sm)
                        .padding(.horizontal, DS.Spacing.md)
                    tasksSection
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    activitiesHeader
                    Divider()
                        .padding(.top, DS.Spacing.sm)
                        .padding(.horizontal, DS.Spacing.md)
                    activitiesSection
                }
            }
            .padding(.vertical, DS.Spacing.md)
        }
        .background(DS.Colors.Background.primary)
        .pullToSearch()
        .navigationTitle("")
        .onAppear {
            lensState.currentScreen = .listingDetail
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                OverflowMenu(actions: listingActions)
            }
        }
        // Alerts
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

    // MARK: - Header Sections

    // Original combined header (kept for iOS)
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Address with progress indicator
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                ProgressCircle(progress: listing.progress, size: 20)
                    .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 2 }

                Text(listing.address)
                    .font(.title.bold())
                    .foregroundColor(DS.Colors.Text.primary)
            }
            metadataContent
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.md)
    }

    // New split metadata section (for macOS)
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            metadataContent
        }
        // No top padding needed as it's the first item in the scroll view
    }

    // Shared internal content
    private var metadataContent: some View {
        Group {
            // Location
            if !listing.city.isEmpty {
                Text("\(listing.city), \(listing.province) \(listing.postalCode)")
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.Text.secondary)
            }
            if owner != nil {
                Divider()
                    .padding(.top, DS.Spacing.sm)
            }

            // Owner pill
            if let owner = owner {
                HStack(spacing: DS.Spacing.xs) {
                    Text(owner.name)
                    .font(DS.Typography.bodySecondary)
                    .foregroundColor(DS.Colors.Text.primary)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.success.opacity(0.15))
                    .clipShape(Capsule())
                }
                .padding(.top, DS.Spacing.xs)
            }
            Divider()
                .padding(.top, DS.Spacing.sm)

            // Listing type
            Text(listing.listingType.rawValue.capitalized)
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.Text.primary)

            // Due date row (simple, text-first)
            if let due = listing.dueDate {
                Divider()
                    .padding(.top, DS.Spacing.sm)

                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "flag")
                        .foregroundColor(DS.Colors.Text.secondary)

                    Text(formattedDueDate(due))
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.Text.primary)

                    Text(relativeDueText(for: due))
                        .font(DS.Typography.bodySecondary)
                        .foregroundColor(relativeDueColor(for: due))
                }
            }
        }
    }

    // MARK: - Section Headers

    private var notesHeader: some View {
        HStack {
            Text("Notes")
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.Text.primary)
            Text("(\(listing.notes.count))")
                .font(DS.Typography.bodySecondary)
                .foregroundColor(DS.Colors.Text.secondary)
            Spacer()
            Button(action: { showNoteInput.toggle() }) {
                Image(systemName: showNoteInput ? DS.Icons.Action.cancel : DS.Icons.Action.add)
                    .font(.system(size: 16))
                    .foregroundColor(DS.Colors.accent)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
    }

    private var tasksHeader: some View {
        HStack {
            Text("Tasks")
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.Text.primary)
            Text("(\(filteredTasks.count))")
                .font(DS.Typography.bodySecondary)
                .foregroundColor(DS.Colors.Text.secondary)
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
    }

    private var activitiesHeader: some View {
        HStack {
            Text("Activities")
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.Text.primary)
            Text("(\(filteredActivities.count))")
                .font(DS.Typography.bodySecondary)
                .foregroundColor(DS.Colors.Text.secondary)
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - Tasks Section

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if filteredTasks.isEmpty {
                emptyStateView(
                    icon: DS.Icons.Entity.task,
                    title: "No Tasks",
                    message: "Tasks for this listing will appear here"
                )
                .padding(.horizontal, DS.Spacing.md)
            } else {
                VStack(spacing: 0) {
                    ForEach(filteredTasks) { task in
                        NavigationLink(value: WorkItemRef.task(task)) {
                            WorkItemRow(
                                item: .task(task),
                                claimState: WorkItem.task(task).claimState(
                                    currentUserId: currentUserId,
                                    userLookup: userLookup
                                ),
                                onClaim: { claimTask(task) },
                                onRelease: { unclaimTask(task) }
                            )
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.xs)
                        }
                        .buttonStyle(.plain)

                        if task.id != filteredTasks.last?.id {
                            Divider()
                                .padding(.leading, DS.Spacing.md)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Activities Section

    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if filteredActivities.isEmpty {
                emptyStateView(
                    icon: DS.Icons.Entity.activity,
                    title: "No Activities",
                    message: "Activities for this listing will appear here"
                )
                .padding(.horizontal, DS.Spacing.md)
            } else {
                VStack(spacing: 0) {
                    ForEach(filteredActivities) { activity in
                        NavigationLink(value: WorkItemRef.activity(activity)) {
                            WorkItemRow(
                                item: .activity(activity),
                                claimState: WorkItem.activity(activity).claimState(
                                    currentUserId: currentUserId,
                                    userLookup: userLookup
                                ),
                                onClaim: { claimActivity(activity) },
                                onRelease: { unclaimActivity(activity) }
                            )
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.xs)
                        }
                        .buttonStyle(.plain)

                        if activity.id != filteredActivities.last?.id {
                            Divider()
                                .padding(.leading, DS.Spacing.md)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
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
                .padding(.horizontal, DS.Spacing.md)
            }

            if listing.notes.isEmpty && !showNoteInput {
                NoteStack.emptyState
                    .padding(.horizontal, DS.Spacing.md)
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
                .padding(.horizontal, DS.Spacing.md)
            }
        }
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
        listing.markPending()
        syncManager.requestSync()
    }

    private func confirmDeleteNote() {
        guard let note = noteToDelete else { return }
        listing.notes.removeAll { $0.id == note.id }
        modelContext.delete(note)
        listing.markPending()
        noteToDelete = nil
        syncManager.requestSync()
    }

    private func deleteListing() {
        listing.status = .deleted
        listing.deletedAt = Date()
        listing.markPending()
        syncManager.requestSync()
        dismiss()
    }

    // MARK: - Task Claim Actions

    private func claimTask(_ task: TaskItem) {
        task.claimedBy = currentUserId
        task.claimedAt = Date()
        task.markPending()

        // ClaimEvent starts as .pending in init
        let event = ClaimEvent(
            parentType: .task,
            parentId: task.id,
            action: .claimed,
            userId: currentUserId
        )
        task.claimHistory.append(event)
        syncManager.requestSync()
    }

    private func unclaimTask(_ task: TaskItem) {
        task.claimedBy = nil
        task.claimedAt = nil
        task.markPending()

        // ClaimEvent starts as .pending in init
        let event = ClaimEvent(
            parentType: .task,
            parentId: task.id,
            action: .released,
            userId: currentUserId
        )
        task.claimHistory.append(event)
        syncManager.requestSync()
    }

    // MARK: - Activity Claim Actions

    private func claimActivity(_ activity: Activity) {
        activity.claimedBy = currentUserId
        activity.claimedAt = Date()
        activity.markPending()

        // ClaimEvent starts as .pending in init
        let event = ClaimEvent(
            parentType: .activity,
            parentId: activity.id,
            action: .claimed,
            userId: currentUserId
        )
        activity.claimHistory.append(event)
        syncManager.requestSync()
    }

    private func unclaimActivity(_ activity: Activity) {
        activity.claimedBy = nil
        activity.claimedAt = nil
        activity.markPending()

        // ClaimEvent starts as .pending in init
        let event = ClaimEvent(
            parentType: .activity,
            parentId: activity.id,
            action: .released,
            userId: currentUserId
        )
        activity.claimHistory.append(event)
        syncManager.requestSync()
    }

    // MARK: - Due Date Helpers

    private static let dueDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "EEE, MMM, d"
        return df
    }()

    private func formattedDueDate(_ date: Date) -> String {
        Self.dueDateFormatter.string(from: date)
    }

    private func relativeDueText(for date: Date) -> String {
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: Date())
        let startDue = cal.startOfDay(for: date)
        let diff = cal.dateComponents([.day], from: startToday, to: startDue).day ?? 0

        if diff == 0 { return "Today" }
        if diff == 1 { return "1 day left" }
        if diff > 1 { return "\(diff) days left" }

        let overdue = abs(diff)
        if overdue == 1 { return "Overdue: 1 day" }
        return "Overdue: \(overdue) days"
    }

    private func relativeDueColor(for date: Date) -> Color {
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: Date())
        let startDue = cal.startOfDay(for: date)
        let diff = cal.dateComponents([.day], from: startToday, to: startDue).day ?? 0
        return diff < 0 ? .red : DS.Colors.Text.secondary
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
        dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())
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
    .environmentObject(LensState())
    .environmentObject(AppOverlayState())
    .environmentObject(SearchPresentationManager())
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

    // Empty listing with no tasks, activities, or notes (overdue)
    let listing = Listing(
        address: "456 Oak Avenue",
        city: "Vancouver",
        province: "BC",
        postalCode: "V6B 1A1",
        price: 2450000,
        listingType: .sale,
        status: .draft,
        ownedBy: ownerUser.id,
        dueDate: Calendar.current.date(byAdding: .day, value: -2, to: Date())
    )
    context.insert(listing)

    let userCache: [UUID: User] = [ownerUser.id: ownerUser]

    return NavigationStack {
        ListingDetailView(listing: listing, userLookup: { userCache[$0] })
    }
    .modelContainer(container)
    .environmentObject(syncManager)
    .environmentObject(LensState())
    .environmentObject(AppOverlayState())
    .environmentObject(SearchPresentationManager())
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
        dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())
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
    .environmentObject(LensState())
    .environmentObject(AppOverlayState())
    .environmentObject(SearchPresentationManager())
}

