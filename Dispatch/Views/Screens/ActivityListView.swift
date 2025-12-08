//
//  ActivityListView.swift
//  Dispatch
//
//  Main screen for displaying and managing activities
//  Created by Claude on 2025-12-06.
//

import SwiftUI
import SwiftData

/// Main activity list screen with:
/// - Segmented filter (My Activities/Others'/Unclaimed)
/// - Date-based sections (Overdue/Today/Tomorrow/Upcoming/No Due Date)
/// - Pull-to-refresh sync
/// - Navigation to activity detail
struct ActivityListView: View {
    @Query(sort: \Activity.dueDate)
    private var allActivitiesRaw: [Activity]

    /// Filter out deleted activities (SwiftData predicates can't compare enums directly)
    private var allActivities: [Activity] {
        allActivitiesRaw.filter { $0.status != .deleted }
    }

    @Query private var users: [User]

    @Query(sort: \Listing.address)
    private var allListings: [Listing]

    /// Active listings for QuickEntrySheet picker
    private var activeListings: [Listing] {
        allListings.filter { $0.status != .deleted }
    }

    @EnvironmentObject private var syncManager: SyncManager
    @Environment(\.modelContext) private var modelContext

    // MARK: - State for Note/Subtask Management

    @State private var showDeleteNoteAlert = false
    @State private var noteToDelete: Note?
    @State private var itemForNoteDeletion: WorkItem?

    @State private var showDeleteSubtaskAlert = false
    @State private var subtaskToDelete: Subtask?
    @State private var itemForSubtaskDeletion: WorkItem?

    @State private var showAddSubtaskSheet = false
    @State private var itemForSubtaskAdd: WorkItem?
    @State private var newSubtaskTitle = ""

    // MARK: - State for Quick Entry
    @State private var showQuickEntry = false

    // MARK: - Computed Properties

    /// Pre-computed user lookup dictionary for O(1) access
    private var userCache: [UUID: User] {
        Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
    }

    /// Activities wrapped as WorkItem for shared component compatibility
    private var workItems: [WorkItem] {
        allActivities.map { .activity($0) }
    }

    /// Sentinel UUID for unauthenticated state - stable across all accesses
    private static let unauthenticatedUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    /// Current user ID from sync manager (fallback to stable sentinel if not set)
    private var currentUserId: UUID {
        syncManager.currentUserID ?? Self.unauthenticatedUserId
    }

    // MARK: - Body

    var body: some View {
        WorkItemListContainer(
            title: "Activities",
            items: workItems,
            currentUserId: currentUserId,
            userLookup: { userCache[$0] },
            onRefresh: {
                await syncManager.sync()
            },
            isActivityList: true,
            rowBuilder: { item, claimedUser in
                NavigationLink(value: WorkItemRef.from(item)) {
                    WorkItemRow(
                        item: item,
                        claimedByUser: claimedUser,
                        onComplete: { toggleComplete(item) },
                        onEdit: {},
                        onDelete: { delete(item) }
                    )
                }
                .buttonStyle(.plain)
            },
            destination: { ref in
                WorkItemResolverView(
                    ref: ref,
                    currentUserId: currentUserId,
                    userLookup: { userCache[$0] },
                    onComplete: { item in toggleComplete(item) },
                    onClaim: { item in claim(item) },
                    onRelease: { item in unclaim(item) },
                    onEditNote: nil,
                    onDeleteNote: { note, item in
                        noteToDelete = note
                        itemForNoteDeletion = item
                        showDeleteNoteAlert = true
                    },
                    onAddNote: { content, item in addNote(to: item, content: content) },
                    onToggleSubtask: { subtask in toggleSubtask(subtask) },
                    onDeleteSubtask: { subtask, item in
                        subtaskToDelete = subtask
                        itemForSubtaskDeletion = item
                        showDeleteSubtaskAlert = true
                    },
                    onAddSubtask: { item in
                        itemForSubtaskAdd = item
                        showAddSubtaskSheet = true
                    }
                )
            }
        )
        // MARK: - Alerts and Sheets
        .alert("Delete Note?", isPresented: $showDeleteNoteAlert) {
            Button("Cancel", role: .cancel) {
                noteToDelete = nil
                itemForNoteDeletion = nil
            }
            Button("Delete", role: .destructive) {
                confirmDeleteNote()
            }
        } message: {
            Text("This note will be permanently deleted.")
        }
        .alert("Delete Subtask?", isPresented: $showDeleteSubtaskAlert) {
            Button("Cancel", role: .cancel) {
                subtaskToDelete = nil
                itemForSubtaskDeletion = nil
            }
            Button("Delete", role: .destructive) {
                confirmDeleteSubtask()
            }
        } message: {
            Text("This subtask will be permanently deleted.")
        }
        .sheet(isPresented: $showAddSubtaskSheet) {
            AddSubtaskSheet(title: $newSubtaskTitle) {
                if let item = itemForSubtaskAdd {
                    addSubtask(to: item, title: newSubtaskTitle)
                }
                newSubtaskTitle = ""
                itemForSubtaskAdd = nil
                showAddSubtaskSheet = false
            }
        }
        .sheet(isPresented: $showQuickEntry) {
            QuickEntrySheet(
                defaultItemType: .activity,
                currentUserId: currentUserId,
                listings: activeListings,
                onSave: { syncManager.requestSync() }
            )
        }
        .overlay(alignment: .bottomTrailing) {
            FloatingActionButton {
                showQuickEntry = true
            }
        }
    }

    // MARK: - Helpers

    private func claimState(for item: WorkItem) -> ClaimState {
        guard let claimedById = item.claimedBy else {
            return .unclaimed
        }
        if claimedById == currentUserId {
            if let user = userCache[claimedById] {
                return .claimedByMe(user: user)
            }
            // Fallback if user not found
            return .claimedByMe(user: User(name: "You", email: "", userType: .realtor))
        } else {
            if let user = userCache[claimedById] {
                return .claimedByOther(user: user)
            }
            return .claimedByOther(user: User(name: "Unknown", email: "", userType: .realtor))
        }
    }

    // MARK: - Actions

    private func toggleComplete(_ item: WorkItem) {
        guard let activity = item.activityItem else { return }
        activity.status = activity.status == .completed ? .open : .completed
        activity.completedAt = activity.status == .completed ? Date() : nil
        activity.updatedAt = Date()
        syncManager.requestSync()
    }

    private func delete(_ item: WorkItem) {
        guard let activity = item.activityItem else { return }
        activity.status = .deleted
        activity.deletedAt = Date()
        activity.updatedAt = Date()
        syncManager.requestSync()
    }

    private func claim(_ item: WorkItem) {
        guard let activity = item.activityItem else { return }
        activity.claimedBy = currentUserId
        activity.claimedAt = Date()
        activity.updatedAt = Date()
        syncManager.requestSync()
    }

    private func unclaim(_ item: WorkItem) {
        guard let activity = item.activityItem else { return }
        activity.claimedBy = nil
        activity.claimedAt = nil
        activity.updatedAt = Date()
        syncManager.requestSync()
    }

    // MARK: - Note Actions

    private func addNote(to item: WorkItem, content: String) {
        guard let activity = item.activityItem else { return }
        let note = Note(
            content: content,
            createdBy: currentUserId,
            parentType: .activity,
            parentId: activity.id
        )
        activity.notes.append(note)
        activity.updatedAt = Date()
        syncManager.requestSync()
    }

    private func confirmDeleteNote() {
        guard let note = noteToDelete, let item = itemForNoteDeletion else { return }
        guard let activity = item.activityItem else { return }
        activity.notes.removeAll { $0.id == note.id }
        modelContext.delete(note)
        activity.updatedAt = Date()
        noteToDelete = nil
        itemForNoteDeletion = nil
        syncManager.requestSync()
    }

    // MARK: - Subtask Actions

    private func toggleSubtask(_ subtask: Subtask) {
        subtask.completed.toggle()
        syncManager.requestSync()
    }

    private func confirmDeleteSubtask() {
        guard let subtask = subtaskToDelete, let item = itemForSubtaskDeletion else { return }
        guard let activity = item.activityItem else { return }
        activity.subtasks.removeAll { $0.id == subtask.id }
        modelContext.delete(subtask)
        activity.updatedAt = Date()
        subtaskToDelete = nil
        itemForSubtaskDeletion = nil
        syncManager.requestSync()
    }

    private func addSubtask(to item: WorkItem, title: String) {
        guard let activity = item.activityItem else { return }
        let subtask = Subtask(
            title: title,
            parentType: .activity,
            parentId: activity.id
        )
        activity.subtasks.append(subtask)
        activity.updatedAt = Date()
        syncManager.requestSync()
    }
}

// MARK: - Preview

#Preview("Activity List View") {
    ActivityListView()
        .modelContainer(for: [Activity.self, User.self], inMemory: true)
        .environmentObject(SyncManager.shared)
}
