//
//  PreviewDataFactory.swift
//  Dispatch
//
//  Canonical source of deterministic data for Previews.
//  Ensures stable UUIDs, dates, and relationship graphs.
//

// swiftlint:disable force_unwrapping

import Foundation
import SwiftData

/// Factory for creating deterministic sample data for previews.
/// Uses fixed UUIDs to ensure stable behavior across preview refreshes.
enum PreviewDataFactory {
  static let aliceID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!
  static let bobID = UUID(uuidString: "660e8400-e29b-41d4-a716-446655440001")!
  static let listingID = UUID(uuidString: "770e8400-e29b-41d4-a716-446655440002")!
  static let carolID = UUID(uuidString: "880e8400-e29b-41d4-a716-446655440003")!
  static let daveID = UUID(uuidString: "990e8400-e29b-41d4-a716-446655440004")!
  static let eveID = UUID(uuidString: "aa0e8400-e29b-41d4-a716-446655440005")!
  static let unknownUserID = UUID(uuidString: "bb0e8400-e29b-41d4-a716-446655440006")!

  /// Seeds the context with a complete graph:
  /// - User Alice (Owner)
  /// - User Bob (Claimer)
  /// - Listing "123 Job Standard Blvd"
  /// - 3 Tasks (Open, Claimed, Completed)
  /// - 2 Activities (Call, Email)
  /// - Notes & History
  static func seed(_ context: ModelContext) {
    // Users
    let alice = User(
      id: aliceID,
      name: "Alice Owner",
      email: "alice@dispatch.com",
      avatarHash: nil,
      userType: .admin
    )
    // Mark synced to avoid sync logic trying to upload
    alice.syncState = EntitySyncState.synced

    let bob = User(
      id: bobID,
      name: "Bob Agent",
      email: "bob@dispatch.com",
      avatarHash: nil,
      userType: .realtor
    )
    bob.syncState = EntitySyncState.synced

    context.insert(alice)
    context.insert(bob)

    // Listing
    let listing = Listing(
      id: listingID,
      address: "123 Job Standard Blvd",
      status: .active,
      ownedBy: aliceID
    )
    listing.dueDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())
    listing.syncState = EntitySyncState.synced
    listing.owner = alice
    context.insert(listing)

    // Tasks
    let taskOpen = TaskItem(
      title: "Inspect Roof",
      status: .open,
      declaredBy: aliceID,
      listingId: listingID
    )
    taskOpen.syncState = EntitySyncState.synced

    let taskClaimed = TaskItem(
      title: "Paint Living Room",
      status: .open,
      declaredBy: aliceID,
      listingId: listingID,
      assigneeUserIds: [bobID]
    )
    taskClaimed.syncState = EntitySyncState.synced

    let taskDone = TaskItem(
      title: "Replace Keybox",
      status: TaskStatus.completed,
      declaredBy: aliceID,
      listingId: listingID
    )
    taskDone.completedAt = Date().addingTimeInterval(-86400)
    taskDone.syncState = EntitySyncState.synced

    listing.tasks.append(contentsOf: [taskOpen, taskClaimed, taskDone])

    // Activities
    let activityCall = Activity(
      title: "Client Call",
      declaredBy: aliceID,
      listingId: listingID
    )
    activityCall.syncState = EntitySyncState.synced

    let activityEmail = Activity(
      title: "Send Docs",
      status: ActivityStatus.completed,
      declaredBy: aliceID,
      listingId: listingID
    )
    activityEmail.syncState = EntitySyncState.synced

    listing.activities.append(contentsOf: [activityCall, activityEmail])

    // Notes
    let note1 = Note(
      content: "Please check for leaks.",
      createdBy: aliceID,
      parentType: .task,
      parentId: taskOpen.id
    )
    note1.createdAt = Date().addingTimeInterval(-3600)
    taskOpen.notes.append(note1)
  }
}
