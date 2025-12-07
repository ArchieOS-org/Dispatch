//
//  WorkItem.swift
//  Dispatch
//
//  Enum wrapper for unified TaskItem/Activity handling in views
//  Created by Claude on 2025-12-06.
//

import SwiftUI

/// A unified wrapper for TaskItem and Activity that provides
/// common computed properties for use in shared view components.
///
/// This enum wrapper approach was chosen over generics because:
/// - Only 2 types need to be unified (TaskItem, Activity)
/// - Explicit pattern matching makes type-specific behavior clear
/// - Simpler to debug and maintain than generic constraints
enum WorkItem: Identifiable {
    case task(TaskItem)
    case activity(Activity)

    // MARK: - Identifiable

    var id: UUID {
        switch self {
        case .task(let task): return task.id
        case .activity(let activity): return activity.id
        }
    }

    // MARK: - Common Properties

    var title: String {
        switch self {
        case .task(let task): return task.title
        case .activity(let activity): return activity.title
        }
    }

    var itemDescription: String {
        switch self {
        case .task(let task): return task.taskDescription
        case .activity(let activity): return activity.activityDescription
        }
    }

    var dueDate: Date? {
        switch self {
        case .task(let task): return task.dueDate
        case .activity(let activity): return activity.dueDate
        }
    }

    var priority: Priority {
        switch self {
        case .task(let task): return task.priority
        case .activity(let activity): return activity.priority
        }
    }

    var claimedBy: UUID? {
        switch self {
        case .task(let task): return task.claimedBy
        case .activity(let activity): return activity.claimedBy
        }
    }

    var notes: [Note] {
        switch self {
        case .task(let task): return task.notes
        case .activity(let activity): return activity.notes
        }
    }

    var subtasks: [Subtask] {
        switch self {
        case .task(let task): return task.subtasks
        case .activity(let activity): return activity.subtasks
        }
    }

    var createdAt: Date {
        switch self {
        case .task(let task): return task.createdAt
        case .activity(let activity): return activity.createdAt
        }
    }

    var updatedAt: Date {
        switch self {
        case .task(let task): return task.updatedAt
        case .activity(let activity): return activity.updatedAt
        }
    }

    var declaredBy: UUID {
        switch self {
        case .task(let task): return task.declaredBy
        case .activity(let activity): return activity.declaredBy
        }
    }

    // MARK: - Status Handling (Type-Specific)

    var isCompleted: Bool {
        switch self {
        case .task(let task): return task.status == .completed
        case .activity(let activity): return activity.status == .completed
        }
    }

    var isDeleted: Bool {
        switch self {
        case .task(let task): return task.status == .deleted
        case .activity(let activity): return activity.status == .deleted
        }
    }

    var statusColor: Color {
        switch self {
        case .task(let task): return DS.Colors.Status.color(for: task.status)
        case .activity(let activity): return DS.Colors.Status.color(for: activity.status)
        }
    }

    var statusIcon: String {
        switch self {
        case .task(let task): return DS.Icons.StatusIcons.icon(for: task.status)
        case .activity(let activity): return DS.Icons.StatusIcons.icon(for: activity.status)
        }
    }

    var statusText: String {
        switch self {
        case .task(let task): return task.status.rawValue.capitalized
        case .activity(let activity): return activity.status.rawValue.capitalized
        }
    }

    // MARK: - Type Label

    var typeLabel: String {
        switch self {
        case .task: return "Task"
        case .activity(let activity):
            switch activity.type {
            case .call: return "Call"
            case .email: return "Email"
            case .meeting: return "Meeting"
            case .showProperty: return "Showing"
            case .followUp: return "Follow-up"
            case .other: return "Activity"
            }
        }
    }

    var typeIcon: String {
        switch self {
        case .task: return DS.Icons.Entity.task
        case .activity(let activity):
            switch activity.type {
            case .call: return DS.Icons.ActivityType.call
            case .email: return DS.Icons.ActivityType.email
            case .meeting: return DS.Icons.ActivityType.meeting
            case .showProperty: return DS.Icons.ActivityType.showProperty
            case .followUp: return DS.Icons.ActivityType.followUp
            case .other: return DS.Icons.ActivityType.other
            }
        }
    }

    // MARK: - Underlying Model Access

    /// Access the underlying TaskItem (if this is a task)
    var taskItem: TaskItem? {
        if case .task(let task) = self { return task }
        return nil
    }

    /// Access the underlying Activity (if this is an activity)
    var activityItem: Activity? {
        if case .activity(let activity) = self { return activity }
        return nil
    }

    // MARK: - Subtask Progress

    var subtaskProgress: Double {
        guard !subtasks.isEmpty else { return 0 }
        let completed = subtasks.filter { $0.completed }.count
        return Double(completed) / Double(subtasks.count)
    }

    var subtaskProgressText: String {
        let completed = subtasks.filter { $0.completed }.count
        return "\(completed)/\(subtasks.count)"
    }
}

// MARK: - Equatable

extension WorkItem: Equatable {
    static func == (lhs: WorkItem, rhs: WorkItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension WorkItem: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
