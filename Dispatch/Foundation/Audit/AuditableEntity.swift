//
//  AuditableEntity.swift
//  Dispatch
//
//  Represents the types of entities that can be audited.
//

import SwiftUI

// MARK: - AuditableEntity

enum AuditableEntity: String, Codable, CaseIterable, Sendable {
  case listing
  case property
  case task
  case user
  case activity
  case taskAssignee = "task_assignee"
  case activityAssignee = "activity_assignee"
  case note

  // MARK: Internal

  var displayName: String {
    switch self {
    case .listing: "Listing"
    case .property: "Property"
    case .task: "Task"
    case .user: "Realtor"
    case .activity: "Activity"
    case .taskAssignee: "Task Assignment"
    case .activityAssignee: "Activity Assignment"
    case .note: "Note"
    }
  }

  var icon: String {
    switch self {
    case .listing: DS.Icons.Entity.listing
    case .property: DS.Icons.Entity.property
    case .task: DS.Icons.Entity.task
    case .user: DS.Icons.Entity.user
    case .activity: DS.Icons.Entity.activity
    case .taskAssignee: DS.Icons.Claim.claimed
    case .activityAssignee: DS.Icons.Claim.claimed
    case .note: DS.Icons.Entity.note
    }
  }

  var tableName: String {
    switch self {
    case .listing: "listings"
    case .property: "properties"
    case .task: "tasks"
    case .user: "users"
    case .activity: "activities"
    case .taskAssignee: "task_assignees_log"
    case .activityAssignee: "activity_assignees_log"
    case .note: "notes_log"
    }
  }

  var color: Color {
    switch self {
    case .listing: DS.Colors.Status.open
    case .property: DS.Colors.Status.inProgress
    case .task: DS.Colors.Status.inProgress
    case .user: DS.Colors.Status.open
    case .activity: DS.Colors.Status.inProgress
    case .taskAssignee: DS.Colors.Status.open
    case .activityAssignee: DS.Colors.Status.open
    case .note: DS.Colors.Status.inProgress
    }
  }

  /// Whether this entity type represents a related audit log (assignments, notes)
  /// as opposed to a primary entity (listing, property, task, etc.)
  var isRelatedEntity: Bool {
    switch self {
    case .taskAssignee, .activityAssignee, .note:
      true
    case .listing, .property, .task, .user, .activity:
      false
    }
  }
}
