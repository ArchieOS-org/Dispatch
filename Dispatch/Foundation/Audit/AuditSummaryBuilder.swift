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

    // Get the assigned user's ID
    let assigneeId = row?["user_id"]?.value as? String

    switch entry.action {
    case .insert:
      // Someone was assigned
      if let assigneeId, assigneeId == actorName || isCurrentActor(assigneeId) {
        return "\(actorName) was assigned to this"
      }
      return "\(actorName) assigned someone to this"

    case .delete:
      // Someone was unassigned
      if let assigneeId, assigneeId == actorName || isCurrentActor(assigneeId) {
        return "\(actorName) was unassigned from this"
      }
      return "\(actorName) unassigned someone from this"

    case .update:
      return "\(actorName) updated assignment"

    case .restore:
      return "\(actorName) restored assignment"
    }
  }

  /// Check if the given ID string represents the current actor
  private func isCurrentActor(_: String) -> Bool {
    // The actorName is the display name, not the UUID, so we can't directly compare
    // This is a simplified check - in practice the caller provides the resolved name
    false
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
      guard let oldValue = oldRow[key], let newValue = newRow[key] else { return false }
      return String(describing: oldValue.value) != String(describing: newValue.value)
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
    let raw = String(describing: value.value)

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
}
