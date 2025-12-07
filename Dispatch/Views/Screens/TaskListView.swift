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

    @EnvironmentObject private var syncManager: SyncManager

    // MARK: - Computed Properties

    /// Pre-computed user lookup dictionary for O(1) access
    private var userCache: [UUID: User] {
        Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
    }

    /// Tasks wrapped as WorkItem for shared component compatibility
    private var workItems: [WorkItem] {
        allTasks.map { .task($0) }
    }

    /// Current user ID from sync manager (fallback to empty UUID if not set)
    private var currentUserId: UUID {
        syncManager.currentUserID ?? UUID()
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
            isActivityList: false
        ) { item, claimedUser in
            NavigationLink(value: item) {
                WorkItemRow(
                    item: item,
                    claimedByUser: claimedUser,
                    onTap: {},
                    onComplete: { toggleComplete(item) },
                    onEdit: {},
                    onDelete: { delete(item) }
                )
            }
            .buttonStyle(.plain)
        }
        .navigationDestination(for: WorkItem.self) { item in
            WorkItemDetailView(
                item: item,
                claimState: claimState(for: item),
                userLookup: { userCache[$0] },
                onComplete: { toggleComplete(item) },
                onClaim: { claim(item) },
                onRelease: { unclaim(item) },
                onAddNote: { _ in },
                onToggleSubtask: { _ in }
            )
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
}

// MARK: - Preview

#Preview("Task List View") {
    TaskListView()
        .modelContainer(for: [TaskItem.self, User.self], inMemory: true)
        .environmentObject(SyncManager.shared)
}
