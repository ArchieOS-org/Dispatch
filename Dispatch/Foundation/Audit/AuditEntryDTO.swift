//
//  AuditEntryDTO.swift
//  Dispatch
//
//  Data Transfer Object for decoding audit entries from Supabase RPC responses.
//

import Foundation

// MARK: - AuditEntryDTO

struct AuditEntryDTO: Codable, Sendable {

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case auditId = "audit_id"
    case action
    case changedAt = "changed_at"
    case changedBy = "changed_by"
    case recordPk = "record_pk"
    case oldRow = "old_row"
    case newRow = "new_row"
    case tableSchema = "table_schema"
    case tableName = "table_name"
  }

  /// Human-readable field labels for display
  static let fieldLabels: [String: String] = [
    // Listing fields
    "stage": "Status",
    "price": "Price",
    "assigned_to": "Assignment",
    "due_date": "Due date",
    "address": "Address",
    "mls_number": "MLS number",
    "owned_by": "Owner",
    "listing_date": "Listing date",
    "expiration_date": "Expiration date",
    "listing_type": "Listing type",
    "commission_rate": "Commission rate",
    "notes": "Notes",
    "real_dirt": "Real dirt",

    // Property fields
    "owner_id": "Owner",
    "property_type": "Property type",
    "bedrooms": "Bedrooms",
    "bathrooms": "Bathrooms",
    "square_feet": "Square feet",
    "lot_size": "Lot size",
    "year_built": "Year built",

    // Task fields
    "title": "Title",
    "description": "Description",
    "status": "Status",
    "priority": "Priority",
    "completed_at": "Completed at",
    "listing_id": "Listing",
    "property_id": "Property",

    // Activity fields
    "declared_by": "Created by",
    "activity_type": "Type",
    "outcome": "Outcome",
    "contact_method": "Contact method",

    // User fields
    "name": "Name",
    "email": "Email",
    "phone": "Phone",
    "license_number": "License number",
    "brokerage": "Brokerage",

    // Assignment fields (task_assignees_log, activity_assignees_log)
    "user_id": "Assignee",
    "assigned_by": "Assigned by",
    "assigned_at": "Assigned at",
    "task_id": "Task",
    "activity_id": "Activity",

    // Note fields (notes_log)
    "content": "Note content",
    "parent_type": "Attached to",
    "parent_id": "Parent",

    // Common fields
    "created_at": "Created at",
    "updated_at": "Updated at"
  ]

  let auditId: UUID
  let action: String
  let changedAt: Date
  let changedBy: UUID?
  let recordPk: UUID
  let oldRow: [String: AnyCodable]?
  let newRow: [String: AnyCodable]?
  let tableSchema: String
  let tableName: String

  func toModel() -> AuditEntry {
    AuditEntry(
      id: auditId,
      action: AuditAction(rawValue: action) ?? .update,
      changedAt: changedAt,
      changedBy: changedBy,
      entityType: entityTypeFromTable(),
      entityId: recordPk,
      summary: computeSummary(),
      oldRow: oldRow,
      newRow: newRow
    )
  }

  // MARK: Private

  private func entityTypeFromTable() -> AuditableEntity {
    switch tableName {
    case "listings": .listing
    case "properties": .property
    case "tasks": .task
    case "users": .user
    case "activities": .activity
    case "task_assignees_log": .taskAssignee
    case "activity_assignees_log": .activityAssignee
    case "notes_log": .note
    default: .listing
    }
  }

  /// Simple action name only - human sentences built by AuditSummaryBuilder at render time
  private func computeSummary() -> String {
    switch action {
    case "INSERT": "Created"
    case "DELETE": "Deleted"
    case "RESTORE": "Restored"
    case "UPDATE": "Updated"
    default: "Modified"
    }
  }
}
