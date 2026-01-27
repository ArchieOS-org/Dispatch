//
//  AuditAction.swift
//  Dispatch
//
//  Represents the type of change recorded in an audit entry.
//

import SwiftUI

// MARK: - AuditAction

enum AuditAction: String, Codable, Sendable {
  case insert = "INSERT"
  case update = "UPDATE"
  case delete = "DELETE"
  case restore = "RESTORE"

  // MARK: Internal

  var displayName: String {
    switch self {
    case .insert: "Created"
    case .update: "Updated"
    case .delete: "Deleted"
    case .restore: "Restored"
    }
  }

  var icon: String {
    switch self {
    case .insert: "plus.circle"
    case .update: "pencil.circle"
    case .delete: "trash.circle"
    case .restore: "arrow.uturn.backward.circle"
    }
  }

  var color: Color {
    switch self {
    case .insert: DS.Colors.Status.open
    case .update: DS.Colors.Status.inProgress
    case .delete: DS.Colors.Status.deleted
    case .restore: DS.Colors.Status.open
    }
  }
}
