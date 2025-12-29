//
//  ListingDetailView.swift
//  Dispatch
//
//  Full detail view for a Listing
//  Refactored for Layout Unification (StandardScreen)
//

import SwiftUI
import SwiftData

struct ListingDetailView: View {
    let listing: Listing
    let userLookup: (UUID) -> User?

    @EnvironmentObject private var syncManager: SyncManager
    @EnvironmentObject private var lensState: LensState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var noteText = ""
    @State private var showNoteInput = false
    @State private var showDeleteNoteAlert = false
    @State private var noteToDelete: Note?
    @State private var showDeleteListingAlert = false

    // MARK: - Computed Properties

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

    private var filteredTasks: [TaskItem] {
        activeTasks.filter { lensState.audience.matches(audiences: $0.audiences) }
    }

    private var filteredActivities: [Activity] {
        activeActivities.filter { lensState.audience.matches(audiences: $0.audiences) }
    }
    
    private var listingActions: [OverflowMenu.Action] {
        [
            OverflowMenu.Action(id: "edit", title: "Edit Listing", icon: DS.Icons.Action.edit) {
                // Edit placeholder
            },
            OverflowMenu.Action(id: "delete", title: "Delete Listing", icon: DS.Icons.Action.delete, role: .destructive) {
                showDeleteListingAlert = true
            }
        ]
    }

    // MARK: - Body

    var body: some View {
        StandardScreen(title: listing.address, layout: .column, scroll: .automatic) {
            content
        } toolbarContent: {
            ToolbarItem(placement: .primaryAction) {
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
        .onAppear {
            lensState.currentScreen = .listingDetail
        }
    }

    // MARK: - Content Sections
    
    private var content: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            metadataSection
            
            VStack(alignment: .leading, spacing: 0) {
                notesHeader
                Divider().padding(.vertical, DS.Spacing.sm)
                notesSection
            }
            
            VStack(alignment: .leading, spacing: 0) {
                tasksHeader
                Divider().padding(.vertical, DS.Spacing.sm)
                tasksSection
            }
            
            VStack(alignment: .leading, spacing: 0) {
                activitiesHeader
                Divider().padding(.vertical, DS.Spacing.sm)
                activitiesSection
            }
        }
        .padding(.vertical, DS.Spacing.md) 
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Location
            if !listing.city.isEmpty {
                Text("\(listing.city), \(listing.province) \(listing.postalCode)")
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.Text.secondary)
            }
            
            if let owner = owner {
                Divider().padding(.top, DS.Spacing.sm)
                
                HStack(spacing: DS.Spacing.xs) {
                    Text(owner.name)
                        .font(DS.Typography.bodySecondary)
                        .foregroundColor(DS.Colors.Text.primary)
                        .padding(.leading, DS.Spacing.md)
                        .padding(.trailing, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(DS.Colors.success.opacity(0.15))
                        .clipShape(Capsule())
                }
                .padding(.top, DS.Spacing.xs)
            }
            
            Divider().padding(.top, DS.Spacing.sm)

            // Listing type
            Text(listing.listingType.rawValue.capitalized)
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.Text.primary)

            // Due date
            if let due = listing.dueDate {
                Divider().padding(.top, DS.Spacing.sm)

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
    }

    // MARK: - List Sections

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if filteredTasks.isEmpty {
                emptyStateView(icon: DS.Icons.Entity.task, title: "No Tasks", message: "Tasks for this listing will appear here")
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
                                onRelease: { unclaimTask(task) },
                                hideDueDate: true
                            )
                            .padding(.vertical, DS.Spacing.xs)
                        }
                        .buttonStyle(.plain)

                        if task.id != filteredTasks.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if filteredActivities.isEmpty {
                emptyStateView(icon: DS.Icons.Entity.activity, title: "No Activities", message: "Activities for this listing will appear here")
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
                                onRelease: { unclaimActivity(activity) },
                                hideDueDate: true
                            )
                            .padding(.vertical, DS.Spacing.xs)
                        }
                        .buttonStyle(.plain)

                        if activity.id != filteredActivities.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

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
            }

            if listing.notes.isEmpty && !showNoteInput {
                NoteStack.emptyState
            } else if !listing.notes.isEmpty {
                NoteStack(
                    notes: listing.notes,
                    userLookup: userLookup,
                    onEdit: nil,
                    onDelete: { note in
                        noteToDelete = note
                        showDeleteNoteAlert = true
                    }
                )
            }
        }
    }

    // MARK: - Actions (Unchanged)
    
    private func addNote(content: String) {
        let note = Note(content: content, createdBy: currentUserId, parentType: .listing, parentId: listing.id)
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

    private func claimTask(_ task: TaskItem) {
        task.claimedBy = currentUserId
        task.claimedAt = Date()
        task.markPending()
        let event = ClaimEvent(parentType: .task, parentId: task.id, action: .claimed, userId: currentUserId)
        task.claimHistory.append(event)
        syncManager.requestSync()
    }

    private func unclaimTask(_ task: TaskItem) {
        task.claimedBy = nil
        task.claimedAt = nil
        task.markPending()
        let event = ClaimEvent(parentType: .task, parentId: task.id, action: .released, userId: currentUserId)
        task.claimHistory.append(event)
        syncManager.requestSync()
    }

    private func claimActivity(_ activity: Activity) {
        activity.claimedBy = currentUserId
        activity.claimedAt = Date()
        activity.markPending()
        let event = ClaimEvent(parentType: .activity, parentId: activity.id, action: .claimed, userId: currentUserId)
        activity.claimHistory.append(event)
        syncManager.requestSync()
    }

    private func unclaimActivity(_ activity: Activity) {
        activity.claimedBy = nil
        activity.claimedAt = nil
        activity.markPending()
        let event = ClaimEvent(parentType: .activity, parentId: activity.id, action: .released, userId: currentUserId)
        activity.claimHistory.append(event)
        syncManager.requestSync()
    }
    
    // MARK: - Helpers

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
        return "Overdue: \(overdue) days"
    }

    private func relativeDueColor(for date: Date) -> Color {
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: Date())
        let startDue = cal.startOfDay(for: date)
        let diff = cal.dateComponents([.day], from: startToday, to: startDue).day ?? 0
        return diff < 0 ? .red : DS.Colors.Text.secondary
    }

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
        .padding(.vertical, DS.Spacing.xl)
    }
}
