//
//  AuditSummaryBuilder.swift
//  Dispatch
//
//  Builds human-readable summaries for audit entries with actor names.
//  Call at display time when actor name is available.
//

import Foundation

// MARK: - AuditSummaryBuilder

struct AuditSummaryBuilder {

  // MARK: Internal

  let entry: AuditEntry
  let actorName: String
  let entityType: AuditableEntity
  /// Optional user lookup for resolving assignee names. Defaults to nil.
  var userLookup: ((UUID) -> User?)? = nil

  /// Build a human-readable summary sentence.
  func build() -> String {
    // Handle special entity types with custom summaries
    switch entityType {
    case .taskAssignee, .activityAssignee:
      return buildAssignmentSummary()
    case .note:
      return buildNoteSummary()
    default:
      break
    }

    // Standard entity summaries
    switch entry.action {
    case .insert:
      return "\(actorName) created this \(entityType.displayName.lowercased())"
    case .delete:
      return "\(actorName) deleted this \(entityType.displayName.lowercased())"
    case .restore:
      return "\(actorName) restored this \(entityType.displayName.lowercased())"
    case .update:
      return buildUpdateSummary()
    }
  }

  // MARK: Private

  // MARK: - Assignment Summaries

  private func buildAssignmentSummary() -> String {
    let row = entry.newRow ?? entry.oldRow

    // Get the assigned user's ID and who assigned them
    let assigneeIdString = row?["user_id"]?.value as? String
    let assignedByIdString = row?["assigned_by"]?.value as? String

    // Parse UUIDs for lookup
    let assigneeId = assigneeIdString.flatMap { UUID(uuidString: $0) }

    // Get assignee name via lookup if available
    let assigneeName: String? = assigneeId.flatMap { userLookup?($0)?.name }

    // Determine if this was a self-assignment (claim) vs assigned by another
    let isSelfAssignment = assigneeIdString != nil && assigneeIdString == assignedByIdString

    switch entry.action {
    case .insert:
      // Someone was assigned
      if isSelfAssignment {
        return "\(actorName) claimed this"
      }
      // actorName is the person who made the change (changedBy = assigned_by)
      if let assigneeName {
        return "\(actorName) assigned \(assigneeName)"
      }
      return "\(actorName) assigned someone"

    case .delete:
      // Someone was unassigned
      // Check if the actor (changedBy) is the same as assignee
      let actorIsAssignee = entry.changedBy != nil && entry.changedBy == assigneeId
      if actorIsAssignee || isSelfAssignment {
        return "\(actorName) removed themselves"
      }
      if let assigneeName {
        return "\(actorName) unassigned \(assigneeName)"
      }
      return "\(actorName) unassigned someone"

    case .update:
      return "\(actorName) updated assignment"

    case .restore:
      if let assigneeName {
        return "\(actorName) restored \(assigneeName)'s assignment"
      }
      return "\(actorName) restored assignment"
    }
  }

  // MARK: - Note Summaries

  private func buildNoteSummary() -> String {
    switch entry.action {
    case .insert:
      "\(actorName) added a note"
    case .update:
      "\(actorName) edited a note"
    case .delete:
      "\(actorName) deleted a note"
    case .restore:
      "\(actorName) restored a note"
    }
  }

  private func buildUpdateSummary() -> String {
    guard let oldRow = entry.oldRow, let newRow = entry.newRow else {
      return "\(actorName) made changes"
    }

    let systemFields = Set(["id", "sync_status", "pending_changes", "created_at", "updated_at"])
    let changedFields = newRow.keys.filter { key in
      guard !systemFields.contains(key) else { return false }
      let oldValue = oldRow[key]
      let newValue = newRow[key]
      return !valuesAreEqual(oldValue, newValue)
    }

    guard !changedFields.isEmpty else { return "\(actorName) made changes" }

    let priorityFields = ["status", "stage", "price", "assigned_to", "title", "name"]
    let topField = priorityFields.first { changedFields.contains($0) } ?? changedFields[0]

    if changedFields.count == 1 {
      return buildSingleFieldSummary(field: topField, oldRow: oldRow, newRow: newRow)
    }

    let humanLabels = changedFields.map { humanLabel(for: $0) }
    if humanLabels.count == 2 {
      return "\(actorName) changed \(humanLabels[0]) and \(humanLabels[1])"
    } else if humanLabels.count == 3 {
      return "\(actorName) changed \(humanLabels[0]), \(humanLabels[1]), and \(humanLabels[2])"
    } else {
      let summary = buildSingleFieldSummary(field: topField, oldRow: oldRow, newRow: newRow)
      let otherCount = changedFields.count - 1
      return "\(summary) and \(otherCount) other field\(otherCount == 1 ? "" : "s")"
    }
  }

  private func buildSingleFieldSummary(
    field: String,
    oldRow: [String: AnyCodable],
    newRow: [String: AnyCodable]
  )
    -> String
  {
    let label = humanLabel(for: field)
    let oldValue = formatValue(oldRow[field], for: field)
    let newValue = formatValue(newRow[field], for: field)

    if ["status", "stage"].contains(field) {
      return "\(actorName) changed \(label.lowercased()) to \(newValue)"
    }
    return "\(actorName) changed \(label.lowercased()) from \(oldValue) to \(newValue)"
  }

  private func humanLabel(for field: String) -> String {
    AuditEntryDTO.fieldLabels[field] ?? field.replacingOccurrences(of: "_", with: " ").capitalized
  }

  private func formatValue(_ value: AnyCodable?, for field: String) -> String {
    guard let value else { return "none" }

    // Extract the actual value from AnyCodable
    let raw = normalizeValue(value)

    if field == "price", let number = Double(raw) {
      let formatter = NumberFormatter()
      formatter.numberStyle = .currency
      formatter.maximumFractionDigits = 0
      return formatter.string(from: NSNumber(value: number)) ?? raw
    }

    if ["status", "stage"].contains(field) {
      return raw.replacingOccurrences(of: "_", with: " ").capitalized
    }

    return raw.isEmpty ? "none" : raw
  }

  /// Compare two AnyCodable values for equality with proper type handling
  private func valuesAreEqual(_ lhs: AnyCodable?, _ rhs: AnyCodable?) -> Bool {
    // Handle nil cases
    switch (lhs, rhs) {
    case (nil, nil):
      true
    case (nil, _), (_, nil):
      false
    case (let left?, let right?):
      normalizeValue(left) == normalizeValue(right)
    }
  }

  /// Normalize an AnyCodable value to a comparable string representation
  private func normalizeValue(_ value: AnyCodable) -> String {
    let raw = value.value

    // Handle NSNull explicitly
    if raw is NSNull {
      return ""
    }

    // Handle common types explicitly for consistent comparison
    switch raw {
    case let bool as Bool:
      return bool ? "true" : "false"
    case let int as Int:
      return String(int)
    case let double as Double:
      // Use fixed precision to avoid floating point comparison issues
      return String(format: "%.6f", double)
    case let string as String:
      return string
    case let uuid as UUID:
      return uuid.uuidString
    default:
      // Fallback to string description
      return String(describing: raw)
    }
  }
}
