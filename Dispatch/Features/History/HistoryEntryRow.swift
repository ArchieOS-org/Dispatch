//
//  HistoryEntryRow.swift
//  Dispatch
//
//  Individual row displaying a single audit history entry.
//

import SwiftUI

// MARK: - HistoryEntryRow

struct HistoryEntryRow: View {

  // MARK: Internal

  let entry: AuditEntry
  let currentUserId: UUID
  let userLookup: (UUID) -> User?
  let onRestore: (() async -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
      HStack {
        Image(systemName: entry.action.icon)
          .foregroundColor(entry.action.color)
          .accessibilityHidden(true)
        Text(entry.action.displayName)
          .font(DS.Typography.headline)
        Spacer()
        if entry.action == .delete, let onRestore {
          restoreButton(onRestore)
        }
      }

      Text(
        AuditSummaryBuilder(
          entry: entry,
          actorName: actorName,
          entityType: entry.entityType,
          userLookup: userLookup
        ).build()
      )
      .font(DS.Typography.caption)
      .foregroundColor(DS.Colors.Text.secondary)

      HStack(spacing: DS.Spacing.xs) {
        Text(entry.changedAt.formatted(date: .abbreviated, time: .shortened))
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.tertiary)

        actorLabel
      }
    }
    .padding(.vertical, DS.Spacing.sm)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
  }

  // MARK: Private

  @State private var isRestoring = false

  private var actorName: String {
    guard let userId = entry.changedBy else { return "System" }
    if userId == currentUserId { return "You" }
    if let user = userLookup(userId) { return user.name }
    return "Someone"
  }

  @ViewBuilder
  private var actorLabel: some View {
    if let userId = entry.changedBy {
      if userId == currentUserId {
        Text("by You")
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.tertiary)
      } else if let user = userLookup(userId) {
        Text("by \(user.name)")
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.tertiary)
      } else {
        Text("by Someone")
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.tertiary)
      }
    } else {
      Text("by System")
        .font(DS.Typography.caption)
        .foregroundColor(DS.Colors.Text.tertiary)
    }
  }

  private var accessibilityLabel: String {
    let summary = AuditSummaryBuilder(
      entry: entry,
      actorName: actorName,
      entityType: entry.entityType,
      userLookup: userLookup
    ).build()
    let timestamp = entry.changedAt.formatted(date: .abbreviated, time: .shortened)
    return "\(summary), \(timestamp)"
  }

  private func restoreButton(_ action: @escaping () async -> Void) -> some View {
    Button {
      Task {
        isRestoring = true
        await action()
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

#Preview("INSERT Entry") {
  HistoryEntryRow(
    entry: .mockInsert,
    currentUserId: PreviewDataFactory.aliceID,
    userLookup: previewUserLookup,
    onRestore: nil
  )
  .padding()
}

#Preview("UPDATE Entry") {
  NavigationStack {
    HistoryEntryRow(
      entry: .mockUpdate,
      currentUserId: PreviewDataFactory.aliceID,
      userLookup: previewUserLookup,
      onRestore: nil
    )
    .padding()
  }
}

#Preview("DELETE Entry with Restore") {
  HistoryEntryRow(
    entry: .mockDelete,
    currentUserId: PreviewDataFactory.aliceID,
    userLookup: previewUserLookup,
    onRestore: { }
  )
  .padding()
}

#Preview("RESTORE Entry") {
  HistoryEntryRow(
    entry: .mockRestore,
    currentUserId: PreviewDataFactory.aliceID,
    userLookup: previewUserLookup,
    onRestore: nil
  )
  .padding()
}

#Preview("All Entry Types") {
  ScrollView {
    VStack(spacing: 0) {
      ForEach(AuditEntry.sampleHistory, id: \.id) { entry in
        HistoryEntryRow(
          entry: entry,
          currentUserId: PreviewDataFactory.aliceID,
          userLookup: previewUserLookup,
          onRestore: entry.action == .delete ? { } : nil
        )
        Divider()
      }
    }
    .padding()
  }
}
