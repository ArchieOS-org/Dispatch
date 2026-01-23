//
//  RecentlyDeletedRow.swift
//  Dispatch
//
//  Row displaying a deleted item in the Recently Deleted list.
//

import SwiftUI

// MARK: - RecentlyDeletedRow

struct RecentlyDeletedRow: View {

  // MARK: Internal

  let entry: AuditEntry
  let onRestore: () async -> Void

  var body: some View {
    HStack(spacing: DS.Spacing.md) {
      Image(systemName: entry.entityType.icon)
        .foregroundColor(entry.entityType.color)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
        Text(entry.displayTitle)
          .font(DS.Typography.body)
          .foregroundColor(DS.Colors.Text.primary)
        Text("\(entry.entityType.displayName) - Deleted \(entry.changedAt.relative)")
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.secondary)
      }

      Spacer()

      Button {
        Task {
          isRestoring = true
          await onRestore()
          isRestoring = false
        }
      } label: {
        if isRestoring {
          ProgressView()
            .controlSize(.small)
        } else {
          Text("Restore")
        }
      }
      .buttonStyle(.bordered)
      .disabled(isRestoring)
    }
    .padding(.vertical, DS.Spacing.xs)
    .contentShape(Rectangle())
  }

  // MARK: Private

  @State private var isRestoring = false
}

// MARK: - Date + relative

extension Date {
  /// Returns a relative date string (e.g., "2 days ago")
  var relative: String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: self, relativeTo: Date())
  }
}

// MARK: - Previews

#Preview("Deleted Listing") {
  RecentlyDeletedRow(entry: .mockDelete) { }
    .padding()
}

#Preview("Deleted Task") {
  RecentlyDeletedRow(entry: .mockDeletedTask) { }
    .padding()
}

#Preview("Deleted Property") {
  RecentlyDeletedRow(entry: .mockDeletedProperty) { }
    .padding()
}

#Preview("All Deleted Types") {
  List {
    RecentlyDeletedRow(entry: .mockDelete) { }
    RecentlyDeletedRow(entry: .mockDeletedTask) { }
    RecentlyDeletedRow(entry: .mockDeletedProperty) { }
  }
}
