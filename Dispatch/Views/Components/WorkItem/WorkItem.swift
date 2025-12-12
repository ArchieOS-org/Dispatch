//
//  WorkItem.swift
//  Dispatch
//
//  Enum wrapper for unified TaskItem/Activity handling in views
//  Created by Claude on 2025-12-06.
//

import SwiftUI

/// Cached snapshot of work item properties for safe rendering.
/// All values are captured at construction time, so they remain valid
/// even if the underlying SwiftData model is invalidated by ModelContext.reset().
struct WorkItemSnapshot {
    let id: UUID
    let title: String
    let itemDescription: String
    let dueDate: Date?
    let priority: Priority
    let claimedBy: UUID?
    let subtaskCount: Int
    let completedSubtaskCount: Int
    let noteCount: Int
    let createdAt: Date
    let updatedAt: Date
    let declaredBy: UUID
    let isCompleted: Bool
    let isDeleted: Bool
    let typeLabel: String
    let typeIcon: String
    let statusRawValue: String

    // For activity type-specific properties
    let activityType: ActivityType?

    // Sync state for per-entity error display
    let syncState: EntitySyncState
    let lastSyncError: String?
}

/// A unified wrapper for TaskItem and Activity that provides
/// common computed properties for use in shared view components.
///
/// This enum wrapper approach was chosen over generics because:
/// - Only 2 types need to be unified (TaskItem, Activity)
/// - Explicit pattern matching makes type-specific behavior clear
/// - Simpler to debug and maintain than generic constraints
///
/// **Critical**: WorkItem caches ALL display properties at construction time.
/// This prevents crashes when SwiftUI renders views after a ModelContext reset
/// has invalidated the underlying SwiftData models. The enum cases still hold
/// model references for mutation operations, but all property access uses cached values.
enum WorkItem: Identifiable {
    case task(TaskItem, snapshot: WorkItemSnapshot)
    case activity(Activity, snapshot: WorkItemSnapshot)

    // MARK: - Identifiable

    var id: UUID {
        snapshot.id
    }

    // MARK: - Snapshot Access

    private var snapshot: WorkItemSnapshot {
        switch self {
        case .task(_, let snapshot): return snapshot
        case .activity(_, let snapshot): return snapshot
        }
    }

    // MARK: - Common Properties (from cached snapshot)

    var title: String { snapshot.title }
    var itemDescription: String { snapshot.itemDescription }
    var dueDate: Date? { snapshot.dueDate }
    var priority: Priority { snapshot.priority }
    var claimedBy: UUID? { snapshot.claimedBy }
    var createdAt: Date { snapshot.createdAt }
    var updatedAt: Date { snapshot.updatedAt }
    var declaredBy: UUID { snapshot.declaredBy }

    // MARK: - Status Handling (from cached snapshot)

    var isCompleted: Bool { snapshot.isCompleted }
    var isDeleted: Bool { snapshot.isDeleted }

    var statusColor: Color {
        if isCompleted {
            return DS.Colors.Status.color(for: TaskStatus.completed)
        } else if isDeleted {
            return DS.Colors.Status.color(for: TaskStatus.deleted)
        } else {
            return DS.Colors.Status.color(for: TaskStatus.open)
        }
    }

    var statusIcon: String {
        if isCompleted {
            return DS.Icons.StatusIcons.icon(for: TaskStatus.completed)
        } else if isDeleted {
            return DS.Icons.StatusIcons.icon(for: TaskStatus.deleted)
        } else {
            return DS.Icons.StatusIcons.icon(for: TaskStatus.open)
        }
    }

    var statusText: String { snapshot.statusRawValue.capitalized }

    // MARK: - Sync State (from cached snapshot)

    var syncState: EntitySyncState { snapshot.syncState }
    var lastSyncError: String? { snapshot.lastSyncError }
    var isSyncFailed: Bool { syncState == .failed }

    // MARK: - Type Label (from cached snapshot)

    var typeLabel: String { snapshot.typeLabel }
    var typeIcon: String { snapshot.typeIcon }

    // MARK: - Subtask Progress (from cached snapshot)

    var subtaskProgress: Double {
        guard snapshot.subtaskCount > 0 else { return 0 }
        return Double(snapshot.completedSubtaskCount) / Double(snapshot.subtaskCount)
    }

    var subtaskProgressText: String {
        "\(snapshot.completedSubtaskCount)/\(snapshot.subtaskCount)"
    }

    var hasSubtasks: Bool {
        snapshot.subtaskCount > 0
    }

    // MARK: - Live Model Access (USE WITH CAUTION)
    // These accessors return the live model for mutation operations.
    // Only use these when you need to modify the model - never for reading display properties.

    /// Access the underlying TaskItem for mutations (if this is a task).
    /// **Warning**: Only use for write operations. Read from cached properties instead.
    var taskItem: TaskItem? {
        if case .task(let task, _) = self { return task }
        return nil
    }

    /// Access the underlying Activity for mutations (if this is an activity).
    /// **Warning**: Only use for write operations. Read from cached properties instead.
    var activityItem: Activity? {
        if case .activity(let activity, _) = self { return activity }
        return nil
    }

    /// Access live notes array from the model.
    /// **Warning**: May crash if model is invalidated. Use noteCount for display.
    var notes: [Note] {
        switch self {
        case .task(let task, _): return task.notes
        case .activity(let activity, _): return activity.notes
        }
    }

    /// Access live subtasks array from the model.
    /// **Warning**: May crash if model is invalidated. Use hasSubtasks/subtaskProgressText for display.
    var subtasks: [Subtask] {
        switch self {
        case .task(let task, _): return task.subtasks
        case .activity(let activity, _): return activity.subtasks
        }
    }
}

// MARK: - Factory Methods

extension WorkItem {
    /// Create a WorkItem wrapping a TaskItem, caching all display properties
    static func task(_ task: TaskItem) -> WorkItem {
        let snapshot = WorkItemSnapshot(
            id: task.id,
            title: task.title,
            itemDescription: task.taskDescription,
            dueDate: task.dueDate,
            priority: task.priority,
            claimedBy: task.claimedBy,
            subtaskCount: task.subtasks.count,
            completedSubtaskCount: task.subtasks.filter { $0.completed }.count,
            noteCount: task.notes.count,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
            declaredBy: task.declaredBy,
            isCompleted: task.status == .completed,
            isDeleted: task.status == .deleted,
            typeLabel: "Task",
            typeIcon: DS.Icons.Entity.task,
            statusRawValue: task.status.rawValue,
            activityType: nil,
            syncState: task.syncState,
            lastSyncError: task.lastSyncError
        )
        return .task(task, snapshot: snapshot)
    }

    /// Create a WorkItem wrapping an Activity, caching all display properties
    static func activity(_ activity: Activity) -> WorkItem {
        let typeLabel: String
        let typeIcon: String
        switch activity.type {
        case .call:
            typeLabel = "Call"
            typeIcon = DS.Icons.ActivityType.call
        case .email:
            typeLabel = "Email"
            typeIcon = DS.Icons.ActivityType.email
        case .meeting:
            typeLabel = "Meeting"
            typeIcon = DS.Icons.ActivityType.meeting
        case .showProperty:
            typeLabel = "Showing"
            typeIcon = DS.Icons.ActivityType.showProperty
        case .followUp:
            typeLabel = "Follow-up"
            typeIcon = DS.Icons.ActivityType.followUp
        case .other:
            typeLabel = "Activity"
            typeIcon = DS.Icons.ActivityType.other
        }

        let snapshot = WorkItemSnapshot(
            id: activity.id,
            title: activity.title,
            itemDescription: activity.activityDescription,
            dueDate: activity.dueDate,
            priority: activity.priority,
            claimedBy: activity.claimedBy,
            subtaskCount: activity.subtasks.count,
            completedSubtaskCount: activity.subtasks.filter { $0.completed }.count,
            noteCount: activity.notes.count,
            createdAt: activity.createdAt,
            updatedAt: activity.updatedAt,
            declaredBy: activity.declaredBy,
            isCompleted: activity.status == .completed,
            isDeleted: activity.status == .deleted,
            typeLabel: typeLabel,
            typeIcon: typeIcon,
            statusRawValue: activity.status.rawValue,
            activityType: activity.type,
            syncState: activity.syncState,
            lastSyncError: activity.lastSyncError
        )
        return .activity(activity, snapshot: snapshot)
    }
}

// MARK: - Equatable

extension WorkItem: Equatable {
    static func == (lhs: WorkItem, rhs: WorkItem) -> Bool {
        // Uses cached ID - safe even if underlying model is invalidated
        lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension WorkItem: Hashable {
    func hash(into hasher: inout Hasher) {
        // Uses cached ID - safe even if underlying model is invalidated
        hasher.combine(id)
    }
}

// MARK: - Claim State Helper

extension WorkItem {
    /// Computes the claim state for this work item relative to the current user.
    /// - Parameters:
    ///   - currentUserId: The ID of the currently authenticated user
    ///   - userLookup: A closure to look up a User by their ID
    /// - Returns: The appropriate ClaimState for display
    func claimState(
        currentUserId: UUID,
        userLookup: (UUID) -> User?
    ) -> ClaimState {
        guard let claimedById = self.claimedBy else {
            return .unclaimed
        }
        if claimedById == currentUserId {
            if let user = userLookup(claimedById) {
                return .claimedByMe(user: user)
            }
            return .claimedByMe(user: User(name: "You", email: "", userType: .realtor))
        } else {
            if let user = userLookup(claimedById) {
                return .claimedByOther(user: user)
            }
            return .claimedByOther(user: User(name: "Unknown", email: "", userType: .realtor))
        }
    }
}
