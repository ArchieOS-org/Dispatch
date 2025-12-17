//
//  TaskItem.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation
import SwiftData

/// Named TaskItem to avoid conflict with Swift's Task type.
/// Represents a work item that can be claimed and completed by staff.
@Model
final class TaskItem: WorkItemProtocol, ClaimableProtocol, NotableProtocol {
    @Attribute(.unique) var id: UUID
    var title: String
    var taskDescription: String
    var dueDate: Date?
    var priority: Priority
    var status: TaskStatus

    // Foreign keys stored as UUIDs
    var declaredBy: UUID
    var claimedBy: UUID?
    var listingId: UUID?

    // Metadata
    var createdVia: CreationSource
    var sourceSlackMessages: [String]?

    // Audience targeting - stored as [String] for SwiftData compatibility
    // Default value at property level required for SwiftData schema migration
    var audiencesRaw: [String] = ["admin", "marketing"]

    /// Computed property exposing audiences as Set<Role>
    var audiences: Set<Role> {
        get {
            Set(audiencesRaw.compactMap { Role(rawValue: $0) })
        }
        set {
            audiencesRaw = newValue.map { $0.rawValue }
        }
    }

    // Timestamps
    var claimedAt: Date?
    var completedAt: Date?
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var syncedAt: Date?

    // Sync state tracking - optional storage with computed wrapper for schema migration compatibility
    var syncStateRaw: EntitySyncState?
    var lastSyncError: String?

    var syncState: EntitySyncState {
        get { syncStateRaw ?? .synced }
        set { syncStateRaw = newValue }
    }

    // Relationships
    @Relationship(deleteRule: .cascade)
    var notes: [Note] = []

    @Relationship(deleteRule: .cascade)
    var subtasks: [Subtask] = []

    @Relationship(deleteRule: .cascade)
    var statusHistory: [StatusChange] = []

    @Relationship(deleteRule: .cascade)
    var claimHistory: [ClaimEvent] = []

    // Inverse relationship (optional)
    var claimedByUser: User?
    var listing: Listing?

    init(
        id: UUID = UUID(),
        title: String,
        taskDescription: String = "",
        dueDate: Date? = nil,
        priority: Priority = .medium,
        status: TaskStatus = .open,
        declaredBy: UUID,
        claimedBy: UUID? = nil,
        listingId: UUID? = nil,
        createdVia: CreationSource = .dispatch,
        sourceSlackMessages: [String]? = nil,
        audiencesRaw: [String] = ["admin", "marketing"],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.taskDescription = taskDescription
        self.dueDate = dueDate
        self.priority = priority
        self.status = status
        self.declaredBy = declaredBy
        self.claimedBy = claimedBy
        self.listingId = listingId
        self.createdVia = createdVia
        self.sourceSlackMessages = sourceSlackMessages
        self.audiencesRaw = audiencesRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStateRaw = .synced
    }
}

// MARK: - RealtimeSyncable Conformance
extension TaskItem: RealtimeSyncable {
    // syncState, lastSyncError, syncedAt are stored properties
    // isDirty, isSyncFailed computed from syncState via protocol extension
    // conflictResolution uses default from protocol extension (.lastWriteWins)

    /// Mark as pending when modified
    func markPending() {
        syncState = .pending
        lastSyncError = nil
        updatedAt = Date()
    }

    /// Mark as synced after successful sync
    func markSynced() {
        syncState = .synced
        lastSyncError = nil
        syncedAt = Date()
    }

    /// Mark as failed with error message
    func markFailed(_ message: String) {
        syncState = .failed
        lastSyncError = message
    }
}
