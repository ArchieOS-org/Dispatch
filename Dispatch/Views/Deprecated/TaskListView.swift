//
//  TaskListView.swift
//  Dispatch
//
//  Main screen for displaying and managing tasks
//  Created by Claude on 2025-12-06.
//

import SwiftUI
import SwiftData

/// Main task list screen with:
/// - Segmented filter (My Tasks/Others'/Unclaimed)
/// - Date-based sections (Overdue/Today/Tomorrow/Upcoming/No Due Date)
/// - Pull-to-refresh sync
/// - Navigation to task detail
///
/// When `embedInNavigationStack` is false, the view omits its NavigationStack wrapper
/// and expects the parent view to provide navigation context (e.g., iPhone menu, iPad split view).
///
/// DEPRECATED: Replaced by MyWorkspaceView filtering.
@available(*, deprecated, message: "Use MyWorkspaceView instead")
struct TaskListView: View {
    /// Whether to wrap content in NavigationStack. Set to false when used in menu/split-view navigation.
    var embedInNavigationStack: Bool = true

    @Query(sort: \TaskItem.dueDate)
    private var allTasksRaw: [TaskItem]

    /// Filter out deleted tasks (SwiftData predicates can't compare enums directly)
    private var allTasks: [TaskItem] {
        allTasksRaw.filter { $0.status != .deleted }
    }

    @Query private var users: [User]

    // macOS listings query removed - QuickEntrySheet now triggered from ContentView

    @EnvironmentObject private var syncManager: SyncManager
    @EnvironmentObject private var lensState: LensState
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

    // macOS quick entry state removed - now handled in ContentView bottom toolbar

    // MARK: - State for Sync Failure Toast
    @State private var showSyncFailedToast = false

    // MARK: - Computed Properties

    /// Pre-computed user lookup dictionary for O(1) access
    private var userCache: [UUID: User] {
        Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
    }

    /// Tasks wrapped as WorkItem for shared component compatibility
    private var workItems: [WorkItem] {
        allTasks.map { .task($0) }
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
            title: "Tasks",
            items: workItems,
            currentUserId: currentUserId,
            userLookup: { userCache[$0] },
            isActivityList: false,
            embedInNavigationStack: embedInNavigationStack,
            rowBuilder: { item, claimState in
                NavigationLink(value: WorkItemRef.from(item)) {
                    WorkItemRow(
                        item: item,
                        claimState: claimState,
                        onComplete: { toggleComplete(item) },
                        onEdit: {},
                        onDelete: { delete(item) },
                        onClaim: { claim(item) },
                        onRelease: { unclaim(item) }
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
        // macOS toolbar removed - bottom toolbar in ContentView handles quick entry
        .alert("Sync Issue", isPresented: $showSyncFailedToast) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We couldn't sync your last change. We'll retry shortly.")
        }
    }

    // MARK: - Actions

    private func toggleComplete(_ item: WorkItem) {
        guard let task = item.taskItem else { return }
        task.status = task.status == .completed ? .open : .completed
        task.completedAt = task.status == .completed ? Date() : nil
        task.markPending()
        syncManager.requestSync()
    }

    private func delete(_ item: WorkItem) {
        guard let task = item.taskItem else { return }
        task.status = .deleted
        task.deletedAt = Date()
        task.markPending()
        syncManager.requestSync()
    }

    private func claim(_ item: WorkItem) {
        guard let task = item.taskItem else { return }
        task.claimedBy = currentUserId
        task.claimedAt = Date()
        task.markPending()

        // Create audit record (ClaimEvent starts as .pending in init)
        let event = ClaimEvent(
            parentType: .task,
            parentId: task.id,
            action: .claimed,
            userId: currentUserId
        )
        task.claimHistory.append(event)

        // Capture sync run ID for correlating with sync result
        let runIdAtStart = syncManager.syncRunId
        syncManager.requestSync()

        // Check for sync failure after delay
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            // Only show toast if we're on or past that run AND in error
            if syncManager.syncRunId >= runIdAtStart,
               case .error = syncManager.syncStatus {
                showSyncFailedToast = true
            }
        }
    }

    private func unclaim(_ item: WorkItem) {
        guard let task = item.taskItem else { return }
        task.claimedBy = nil
        task.claimedAt = nil
        task.markPending()

        // Create audit record (ClaimEvent starts as .pending in init)
        let event = ClaimEvent(
            parentType: .task,
            parentId: task.id,
            action: .released,
            userId: currentUserId
        )
        task.claimHistory.append(event)

        // Capture sync run ID for correlating with sync result
        let runIdAtStart = syncManager.syncRunId
        syncManager.requestSync()

        // Check for sync failure after delay
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            // Only show toast if we're on or past that run AND in error
            if syncManager.syncRunId >= runIdAtStart,
               case .error = syncManager.syncStatus {
                showSyncFailedToast = true
            }
        }
    }

    // MARK: - Note Actions

    private func addNote(to item: WorkItem, content: String) {
        guard let task = item.taskItem else { return }
        let note = Note(
            content: content,
            createdBy: currentUserId,
            parentType: .task,
            parentId: task.id
        )
        task.notes.append(note)
        task.markPending()
        syncManager.requestSync()
    }

    private func confirmDeleteNote() {
        guard let note = noteToDelete, let item = itemForNoteDeletion else { return }
        guard let task = item.taskItem else { return }
        task.notes.removeAll { $0.id == note.id }
        modelContext.delete(note)
        task.markPending()
        noteToDelete = nil
        itemForNoteDeletion = nil
        syncManager.requestSync()
    }

    // MARK: - Subtask Actions

    private func toggleSubtask(_ subtask: Subtask) {
        subtask.completed.toggle()
        // Note: Subtasks sync with parent task - parent will be marked pending when saved
        syncManager.requestSync()
    }

    private func confirmDeleteSubtask() {
        guard let subtask = subtaskToDelete, let item = itemForSubtaskDeletion else { return }
        guard let task = item.taskItem else { return }
        task.subtasks.removeAll { $0.id == subtask.id }
        modelContext.delete(subtask)
        task.markPending()
        subtaskToDelete = nil
        itemForSubtaskDeletion = nil
        syncManager.requestSync()
    }

    private func addSubtask(to item: WorkItem, title: String) {
        guard let task = item.taskItem else { return }
        let subtask = Subtask(
            title: title,
            parentType: .task,
            parentId: task.id
        )
        task.subtasks.append(subtask)
        task.markPending()
        syncManager.requestSync()
    }
}

// MARK: - Preview

#Preview("Task List View") {
    Text("Deprecated")
}

@MainActor
private func setupPreview() -> (ModelContainer, SyncManager) {
    let container = try! ModelContainer(
        for: TaskItem.self, User.self, Note.self, Subtask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let syncManager = SyncManager()
    let context = container.mainContext
    
    // Create users
    let currentUser = User(
        name: "Alice Johnson",
        email: "alice@dispatch.ca",
        userType: .admin
    )
    context.insert(currentUser)
    
    let otherUser = User(
        name: "Bob Smith",
        email: "bob@dispatch.ca",
        userType: .admin
    )
    context.insert(otherUser)
    
    // Configure sync manager
    syncManager.configure(with: container)
    syncManager.currentUserID = currentUser.id
    
    // Create overdue task
    let overdueTask = TaskItem(
        title: "Order title search",
        taskDescription: "Contact Stewart Title for property search",
        dueDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
        priority: .high,
        status: .open,
        declaredBy: currentUser.id
    )
    context.insert(overdueTask)
    
    // Create today task
    let todayTask = TaskItem(
        title: "Client meeting prep",
        taskDescription: "Prepare documents for 2pm meeting",
        dueDate: Date(),
        priority: .medium,
        status: .inProgress,
        declaredBy: currentUser.id
    )
    context.insert(todayTask)
    
    // Create tomorrow task (claimed by other user)
    let tomorrowTask = TaskItem(
        title: "Prepare condition waiver",
        taskDescription: "Draft waiver documents for buyer signature",
        dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
        priority: .high,
        status: .open,
        declaredBy: currentUser.id,
        claimedBy: otherUser.id
    )
    tomorrowTask.claimedAt = Date()
    context.insert(tomorrowTask)
    
    // Create upcoming task (unclaimed)
    let upcomingTask = TaskItem(
        title: "Request mortgage approval letter",
        taskDescription: "Follow up with TD Bank mortgage specialist",
        dueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
        priority: .low,
        status: .open,
        declaredBy: currentUser.id
    )
    context.insert(upcomingTask)
    
    // Create completed task
    let completedTask = TaskItem(
        title: "Coordinate key exchange",
        taskDescription: "Arrange handover at closing - confirm lockbox code",
        dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
        priority: .medium,
        status: .completed,
        declaredBy: currentUser.id,
        claimedBy: currentUser.id
    )
    completedTask.claimedAt = Calendar.current.date(byAdding: .day, value: -2, to: Date())
    completedTask.completedAt = Date()
    context.insert(completedTask)
    
    // Create task with no due date
    let noDueDateTask = TaskItem(
        title: "Update client database",
        taskDescription: "Enter new client information into system",
        dueDate: nil,
        priority: .medium,
        status: .open,
        declaredBy: currentUser.id
    )
    context.insert(noDueDateTask)
    
    return (container, syncManager)
}
