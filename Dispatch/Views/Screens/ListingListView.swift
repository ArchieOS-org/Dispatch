//
//  ListingListView.swift
//  Dispatch
//
//  Main screen for displaying and managing listings
//  Refactored for Layout Unification (StandardScreen)
//

import SwiftUI
import SwiftData

/// A group of listings belonging to a single owner
private struct ListingGroup: Identifiable {
    var id: String { owner?.id.uuidString ?? "unknown" }
    let owner: User?
    let listings: [Listing]
}

struct ListingListView: View {
    /// Whether to wrap content in NavigationStack. Set to false when used in menu/split-view navigation.
    var embedInNavigationStack: Bool = true
    
    @Query(sort: \Listing.address)
    private var allListingsRaw: [Listing]

    /// Filter out deleted listings
    private var allListings: [Listing] {
        allListingsRaw.filter { $0.status != .deleted }
    }

    @Query private var users: [User]

    @EnvironmentObject private var syncManager: SyncManager
    @EnvironmentObject private var lensState: LensState
    @Environment(\.modelContext) private var modelContext

    // MARK: - State for Note/Subtask Management (for drill-down)

    @State private var showDeleteNoteAlert = false
    @State private var noteToDelete: Note?
    @State private var itemForNoteDeletion: WorkItem?

    @State private var showDeleteSubtaskAlert = false
    @State private var subtaskToDelete: Subtask?
    @State private var itemForSubtaskDeletion: WorkItem?

    @State private var showAddSubtaskSheet = false
    @State private var itemForSubtaskAdd: WorkItem?
    @State private var newSubtaskTitle = ""

    // MARK: - Computed Properties

    /// Pre-computed user lookup dictionary for O(1) access
    private var userCache: [UUID: User] {
        Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
    }

    /// Listings grouped by owner, sorted by owner name
    private var groupedByOwner: [ListingGroup] {
        let grouped = Dictionary(grouping: allListings) { $0.ownedBy }
        return grouped.map { ListingGroup(owner: userCache[$0.key], listings: $0.value) }
            .sorted { ($0.owner?.name ?? "~") < ($1.owner?.name ?? "~") }
    }

    /// Whether the list is empty
    private var isEmpty: Bool {
        allListings.isEmpty
    }

    private static let unauthenticatedUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    private var currentUserId: UUID {
        syncManager.currentUserID ?? Self.unauthenticatedUserId
    }

    // MARK: - Body

    var body: some View {
        Group {
            if embedInNavigationStack {
                NavigationStack {
                    mainScreen
                }
            } else {
                mainScreen
            }
        }
        .onAppear {
            lensState.currentScreen = .listings
        }
        // MARK: - Alerts
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
    }
    
    private var mainScreen: some View {
        StandardScreen(title: "Listings", layout: .column, scroll: .disabled) {
            // Content
            StandardList(groupedByOwner) { group in
                Section(group.owner?.name ?? "Unknown Owner") {
                    ForEach(group.listings) { listing in
                        NavigationLink(value: listing) {
                            ListingRow(listing: listing, owner: group.owner)
                        }
                    }
                }
            } emptyContent: {
                ContentUnavailableView {
                    Label("No Listings", systemImage: DS.Icons.Entity.listing)
                } description: {
                    Text("Listings will appear here")
                }
            }
            .pullToSearch() // Apply search to the list context
            
        } toolbarContent: {
             ToolbarItem(placement: .automatic) {
                 EmptyView()
             }
        }
        .navigationDestination(for: Listing.self) { listing in
            ListingDetailView(listing: listing, userLookup: { userCache[$0] })
        }
        .navigationDestination(for: WorkItemRef.self) { ref in
            workItemDestination(for: ref)
        }
    }

    @ViewBuilder
    private func workItemDestination(for ref: WorkItemRef) -> some View {
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

    // MARK: - Actions (Unchanged Logic)
    
    private func toggleComplete(_ item: WorkItem) {
        switch item {
        case .task(let task, _):
            task.status = task.status == .completed ? .open : .completed
            task.completedAt = task.status == .completed ? Date() : nil
            task.markPending()
        case .activity(let activity, _):
            activity.status = activity.status == .completed ? .open : .completed
            activity.completedAt = activity.status == .completed ? Date() : nil
            activity.markPending()
        }
        syncManager.requestSync()
    }

    private func claim(_ item: WorkItem) {
        switch item {
        case .task(let task, _):
            task.claimedBy = currentUserId
            task.claimedAt = Date()
            task.markPending()
        case .activity(let activity, _):
            activity.claimedBy = currentUserId
            activity.claimedAt = Date()
            activity.markPending()
        }
        syncManager.requestSync()
    }

    private func unclaim(_ item: WorkItem) {
        switch item {
        case .task(let task, _):
            task.claimedBy = nil
            task.claimedAt = nil
            task.markPending()
        case .activity(let activity, _):
            activity.claimedBy = nil
            activity.claimedAt = nil
            activity.markPending()
        }
        syncManager.requestSync()
    }

    private func addNote(to item: WorkItem, content: String) {
        switch item {
        case .task(let task, _):
            let note = Note(content: content, createdBy: currentUserId, parentType: .task, parentId: item.id)
            task.notes.append(note)
            task.markPending()
        case .activity(let activity, _):
            let note = Note(content: content, createdBy: currentUserId, parentType: .activity, parentId: item.id)
            activity.notes.append(note)
            activity.markPending()
        }
        syncManager.requestSync()
    }

    private func confirmDeleteNote() {
        guard let note = noteToDelete, let item = itemForNoteDeletion else { return }
        switch item {
        case .task(let task, _):
            task.notes.removeAll { $0.id == note.id }
            task.markPending()
        case .activity(let activity, _):
            activity.notes.removeAll { $0.id == note.id }
            activity.markPending()
        }
        modelContext.delete(note)
        noteToDelete = nil
        itemForNoteDeletion = nil
        syncManager.requestSync()
    }

    private func toggleSubtask(_ subtask: Subtask) {
        subtask.completed.toggle()
        syncManager.requestSync()
    }

    private func confirmDeleteSubtask() {
        guard let subtask = subtaskToDelete, let item = itemForSubtaskDeletion else { return }
        switch item {
        case .task(let task, _):
            task.subtasks.removeAll { $0.id == subtask.id }
            task.markPending()
        case .activity(let activity, _):
            activity.subtasks.removeAll { $0.id == subtask.id }
            activity.markPending()
        }
        modelContext.delete(subtask)
        subtaskToDelete = nil
        itemForSubtaskDeletion = nil
        syncManager.requestSync()
    }

    private func addSubtask(to item: WorkItem, title: String) {
        switch item {
        case .task(let task, _):
            let subtask = Subtask(title: title, parentType: .task, parentId: item.id)
            task.subtasks.append(subtask)
            task.markPending()
        case .activity(let activity, _):
            let subtask = Subtask(title: title, parentType: .activity, parentId: item.id)
            activity.subtasks.append(subtask)
            activity.markPending()
        }
        syncManager.requestSync()
    }
}

// MARK: - Preview
#Preview("Listing List View") {
    ListingListView()
        .modelContainer(for: [Listing.self, User.self], inMemory: true)
        .environmentObject(SyncManager.shared)
        .environmentObject(LensState())
}
