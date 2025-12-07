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

    @EnvironmentObject private var syncManager: SyncManager

    // MARK: - Computed Properties

    /// Pre-computed user lookup dictionary for O(1) access
    private var userCache: [UUID: User] {
        Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
    }

    /// Activities wrapped as WorkItem for shared component compatibility
    private var workItems: [WorkItem] {
        allActivities.map { .activity($0) }
    }

    /// Current user ID from sync manager (fallback to empty UUID if not set)
    private var currentUserId: UUID {
        syncManager.currentUserID ?? UUID()
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
            isActivityList: true
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
}

// MARK: - Preview

#Preview("Activity List View") {
    ActivityListView()
        .modelContainer(for: [Activity.self, User.self], inMemory: true)
        .environmentObject(SyncManager.shared)
}
