//
//  HistoryDetailView.swift
//  Dispatch
//
//  Diff view showing changes for an UPDATE audit entry.
//

import SwiftUI

// MARK: - HistoryDetailView

struct HistoryDetailView: View {

  // MARK: Internal

  let entry: AuditEntry
  let userLookup: (UUID) -> User?

  var body: some View {
    StandardScreen(title: entry.action.displayName, layout: .column, scroll: .automatic) {
      VStack(alignment: .leading, spacing: DS.Spacing.lg) {
        metadata
        changesSection
      }
    }
  }

  // MARK: Private

  private var metadata: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
      Text(entry.changedAt.formatted(date: .long, time: .shortened))
        .font(DS.Typography.body)
        .foregroundColor(DS.Colors.Text.secondary)

      if let userId = entry.changedBy, let user = userLookup(userId) {
        Text("by \(user.name)")
          .font(DS.Typography.body)
          .foregroundColor(DS.Colors.Text.secondary)
      }
    }
  }

  @ViewBuilder
  private var changesSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      Text("Changes")
        .font(DS.Typography.headline)
      Divider()

      if let diffs = computeDiffs() {
        ForEach(diffs, id: \.field) { diff in
          DiffRow(diff: diff)
        }
      } else {
        Text("Unable to compute changes")
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.tertiary)
      }
    }
  }

  private func computeDiffs() -> [FieldDiff]? {
    guard let oldRow = entry.oldRow, let newRow = entry.newRow else { return nil }

    let ignored = Set(["id", "sync_status", "pending_changes", "created_at", "updated_at"])
    let keys = Set(oldRow.keys).union(newRow.keys).subtracting(ignored)

    let diffs = keys.compactMap { key -> FieldDiff? in
      let oldVal = stringify(oldRow[key]?.value)
      let newVal = stringify(newRow[key]?.value)
      guard oldVal != newVal else { return nil }

      let label = AuditEntryDTO.fieldLabels[key] ?? key.replacingOccurrences(of: "_", with: " ").capitalized
      return FieldDiff(
        field: label,
        oldValue: formatDiffValue(oldVal, for: key),
        newValue: formatDiffValue(newVal, for: key)
      )
    }

    return diffs.sorted { $0.field < $1.field }
  }

  private func stringify(_ any: Any?) -> String {
    guard let any else { return "" }
    if let s = any as? String { return s }
    if let n = any as? NSNumber { return n.stringValue }
    return String(describing: any)
  }

  private func formatDiffValue(_ value: String, for field: String) -> String {
    if value.isEmpty { return "none" }

    // Format prices
    if field == "price", let number = Double(value) {
      let formatter = NumberFormatter()
      formatter.numberStyle = .currency
      formatter.maximumFractionDigits = 0
      return formatter.string(from: NSNumber(value: number)) ?? value
    }

    // Format dates
    if field.contains("date") || field.contains("_at"), let date = ISO8601DateFormatter().date(from: value) {
      return date.formatted(date: .abbreviated, time: .shortened)
    }

    // Format booleans
    if value == "true" { return "Yes" }
    if value == "false" { return "No" }

    // Format UUIDs (show first 8 chars)
    if value.count == 36, value.contains("-") {
      return String(value.prefix(8)) + "..."
    }

    return value
  }
}

// MARK: - FieldDiff

struct FieldDiff {
  let field: String
  let oldValue: String
  let newValue: String
}

// MARK: - DiffRow

struct DiffRow: View {
  let diff: FieldDiff

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
      Text(diff.field.capitalized)
        .font(DS.Typography.headline)

      HStack {
        Text("- \(diff.oldValue)")
          .font(DS.Typography.body)
          .foregroundColor(DS.Colors.Status.deleted)
        Spacer()
        Text("OLD")
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.tertiary)
      }

      HStack {
        Text("+ \(diff.newValue)")
          .font(DS.Typography.body)
          .foregroundColor(DS.Colors.Status.open)
        Spacer()
        Text("NEW")
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.tertiary)
      }
    }
    .padding(.vertical, DS.Spacing.sm)
  }
}

// MARK: - Preview Helpers

private func previewUserLookup(_ id: UUID) -> User? {
  if id == PreviewDataFactory.aliceID {
    return User(
      id: PreviewDataFactory.aliceID,
      name: "Alice Owner",
      email: "alice@dispatch.com",
      userType: .admin
    )
  } else if id == PreviewDataFactory.bobID {
    return User(
      id: PreviewDataFactory.bobID,
      name: "Bob Agent",
      email: "bob@dispatch.com",
      userType: .realtor
    )
  }
  return nil
}

// MARK: - Previews

#Preview("Update Entry Diff") {
  NavigationStack {
    HistoryDetailView(
      entry: .mockUpdate,
      userLookup: previewUserLookup
    )
  }
}

#Preview("Update Entry with Many Fields") {
  let entry = AuditEntry(
    id: UUID(),
    action: .update,
    changedAt: Date().addingTimeInterval(-3600),
    changedBy: PreviewDataFactory.aliceID,
    entityType: .listing,
    entityId: UUID(),
    summary: "Updated",
    oldRow: [
      "price": AnyCodable(500_000),
      "stage": AnyCodable("active"),
      "address": AnyCodable("123 Main St"),
      "due_date": AnyCodable("2025-01-15T10:00:00Z"),
      "notes": AnyCodable("Original notes")
    ],
    newRow: [
      "price": AnyCodable(475_000),
      "stage": AnyCodable("pending"),
      "address": AnyCodable("123 Main Street"),
      "due_date": AnyCodable("2025-01-20T10:00:00Z"),
      "notes": AnyCodable("Updated notes with more details")
    ]
  )

  NavigationStack {
    HistoryDetailView(
      entry: entry,
      userLookup: previewUserLookup
    )
  }
}

#Preview("Insert Entry (No Diff)") {
  NavigationStack {
    HistoryDetailView(
      entry: .mockInsert,
      userLookup: previewUserLookup
    )
  }
}
