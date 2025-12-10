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
struct TaskListView: View {
    @Query(sort: \TaskItem.dueDate)
    private var allTasksRaw: [TaskItem]

    /// Filter out deleted tasks (SwiftData predicates can't compare enums directly)
    private var allTasks: [TaskItem] {
        allTasksRaw.filter { $0.status != .deleted }
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
            onRefresh: {
                await syncManager.sync()
            },
            isActivityList: false,
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
                defaultItemType: .task,
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

    // MARK: - Actions

    private func toggleComplete(_ item: WorkItem) {
        guard let task = item.taskItem else { return }
        task.status = task.status == .completed ? .open : .completed
        task.completedAt = task.status == .completed ? Date() : nil
        task.updatedAt = Date()
        syncManager.requestSync()
    }

    private func delete(_ item: WorkItem) {
        guard let task = item.taskItem else { return }
        task.status = .deleted
        task.deletedAt = Date()
        task.updatedAt = Date()
        syncManager.requestSync()
    }

    private func claim(_ item: WorkItem) {
        guard let task = item.taskItem else { return }
        task.claimedBy = currentUserId
        task.claimedAt = Date()
        task.updatedAt = Date()
        syncManager.requestSync()
    }

    private func unclaim(_ item: WorkItem) {
        guard let task = item.taskItem else { return }
        task.claimedBy = nil
        task.claimedAt = nil
        task.updatedAt = Date()
        syncManager.requestSync()
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
        task.updatedAt = Date()
        syncManager.requestSync()
    }

    private func confirmDeleteNote() {
        guard let note = noteToDelete, let item = itemForNoteDeletion else { return }
        guard let task = item.taskItem else { return }
        task.notes.removeAll { $0.id == note.id }
        modelContext.delete(note)
        task.updatedAt = Date()
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
        guard let task = item.taskItem else { return }
        task.subtasks.removeAll { $0.id == subtask.id }
        modelContext.delete(subtask)
        task.updatedAt = Date()
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
        task.updatedAt = Date()
        syncManager.requestSync()
    }
}

// MARK: - Preview

#Preview("Task List View") {
    @Previewable @State var syncManager = SyncManager.shared
    
    let container = try! ModelContainer(
        for: TaskItem.self, User.self, Note.self, Subtask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    // Create preview data
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
    
    // Set current user
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
    
    // Create today task (claimed by current user)
    let todayTask = TaskItem(
        title: "Schedule home inspection",
        taskDescription: "Book with certified inspector - 3 hour window needed",
        dueDate: Calendar.current.startOfDay(for: Date()),
        priority: .medium,
        status: .open,
        declaredBy: currentUser.id,
        claimedBy: currentUser.id
    )
    todayTask.claimedAt = Date()
    context.insert(todayTask)
    
    // Add a note to today's task
    let note1 = Note(
        content: "Inspector prefers morning appointments",
        createdBy: currentUser.id,
        parentType: .task,
        parentId: todayTask.id
    )
    todayTask.notes.append(note1)
    
    // Add subtasks to today's task
    let subtask1 = Subtask(
        title: "Call inspector for availability",
        parentType: .task,
        parentId: todayTask.id
    )
    subtask1.completed = true
    todayTask.subtasks.append(subtask1)
    
    let subtask2 = Subtask(
        title: "Confirm with client",
        parentType: .task,
        parentId: todayTask.id
    )
    todayTask.subtasks.append(subtask2)
    
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
    
    return TaskListView()
        .modelContainer(container)
        .environmentObject(syncManager)
}
