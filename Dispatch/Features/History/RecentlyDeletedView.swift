//
// MARK: - RecentlyDeletedView
//
// Shows recently deleted items with restore capability.
//

import Supabase
import SwiftUI

// MARK: - RecentlyDeletedView

struct RecentlyDeletedView: View {

  // MARK: Internal

  let supabase: SupabaseClient

  var body: some View {
    // Use scroll: .disabled when showing List, since List has its own scrolling.
    // StandardScreen with scroll: .automatic wraps content in ScrollView,
    // which conflicts with List's internal scrolling and causes List to collapse.
    StandardScreen(
      title: "Recently Deleted",
      layout: .column,
      scroll: showList ? .disabled : .automatic
    ) {
      content
    }
    .task { await loadDeletedItems() }
    .navigationDestination(item: $restoredEntityNavigation) { nav in
      destinationView(for: nav.type, id: nav.entityId)
    }
  }

  // MARK: Private

  @State private var entries: [AuditEntry] = []
  @State private var filter: AuditableEntity?
  @State private var isLoading = true
  @State private var error: Error?
  @State private var restoredEntityNavigation: RestoredNavTarget?

  private var filteredEntries: [AuditEntry] {
    guard let filter else { return entries }
    return entries.filter { $0.entityType == filter }
  }

  /// Whether the list should be shown (determines scroll mode)
  private var showList: Bool {
    !isLoading && error == nil && !filteredEntries.isEmpty
  }

  @ViewBuilder
  private var content: some View {
    filterPicker

    if isLoading {
      loadingState
    } else if let error {
      errorState(error)
    } else if filteredEntries.isEmpty {
      emptyState
    } else {
      List {
        groupedList
      }
      #if os(iOS)
      .listStyle(.insetGrouped)
      #endif
    }
  }

  private var filterPicker: some View {
    Picker("Filter", selection: $filter) {
      Text("All").tag(nil as AuditableEntity?)
      ForEach(AuditableEntity.allCases, id: \.self) { entity in
        Text(entity.displayName).tag(entity as AuditableEntity?)
      }
    }
    .pickerStyle(.segmented)
    .padding(.horizontal, DS.Spacing.md)
  }

  private var loadingState: some View {
    VStack(spacing: DS.Spacing.md) {
      ProgressView()
      Text("Loading...")
        .font(DS.Typography.caption)
        .foregroundColor(DS.Colors.Text.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var emptyState: some View {
    VStack(spacing: DS.Spacing.md) {
      Image(systemName: "trash")
        .font(.system(size: 48))
        .foregroundColor(DS.Colors.Text.tertiary)
        .accessibilityHidden(true)
      Text("No deleted items")
        .font(DS.Typography.headline)
        .foregroundColor(DS.Colors.Text.secondary)
      Text("Items you delete will appear here")
        .font(DS.Typography.caption)
        .foregroundColor(DS.Colors.Text.tertiary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var groupedList: some View {
    let grouped = Dictionary(grouping: filteredEntries) { entry in
      Calendar.current.startOfDay(for: entry.changedAt)
    }
    let sortedDates = grouped.keys.sorted(by: >)

    return ForEach(sortedDates, id: \.self) { date in
      Section(header: Text(date.formatted(date: .abbreviated, time: .omitted))) {
        ForEach(grouped[date] ?? [], id: \.id) { entry in
          RecentlyDeletedRow(entry: entry) {
            await restoreEntry(entry)
          }
        }
      }
    }
  }

  private func errorState(_: Error) -> some View {
    VStack(spacing: DS.Spacing.md) {
      Image(systemName: DS.Icons.Alert.error)
        .font(.system(size: 48))
        .foregroundColor(DS.Colors.destructive)
        .accessibilityHidden(true)
      Text("Failed to load")
        .font(DS.Typography.headline)
        .foregroundColor(DS.Colors.Text.secondary)
      Button("Retry") {
        Task { await loadDeletedItems() }
      }
      .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private func destinationView(for entityType: AuditableEntity, id: UUID) -> some View {
    // Note: These views would need ID-based initializers.
    // For now, show a placeholder. Integration will require finding the entity.
    Text("Restored \(entityType.displayName): \(id.uuidString.prefix(8))...")
      .font(DS.Typography.body)
  }

  private func loadDeletedItems() async {
    isLoading = true
    error = nil
    do {
      entries = try await AuditSyncHandler(supabase: supabase).fetchRecentlyDeleted()
    } catch {
      self.error = error
    }
    isLoading = false
  }

  private func restoreEntry(_ entry: AuditEntry) async {
    do {
      let restoredId = try await AuditSyncHandler(supabase: supabase)
        .restoreEntity(entry.entityType, entityId: entry.entityId)
      // Remove from list
      Task { @MainActor in
        entries.removeAll { $0.id == entry.id }
        restoredEntityNavigation = RestoredNavTarget(type: entry.entityType, entityId: restoredId)
      }
    } catch {
      Task { @MainActor in
        self.error = error
      }
    }
  }
}

// MARK: - RecentlyDeletedPreview

/// A preview-friendly wrapper that displays recently deleted items with injected mock data.
private struct RecentlyDeletedPreview: View {

  // MARK: Internal

  let entries: [AuditEntry]
  let isLoading: Bool

  var body: some View {
    // Use scroll: .disabled when showing List, since List has its own scrolling.
    // StandardScreen with scroll: .automatic wraps content in ScrollView,
    // which conflicts with List's internal scrolling and causes List to collapse.
    StandardScreen(
      title: "Recently Deleted",
      layout: .column,
      scroll: showList ? .disabled : .automatic
    ) {
      filterPicker

      if isLoading {
        loadingState
      } else if filteredEntries.isEmpty {
        emptyState
      } else {
        List {
          groupedList
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
      }
    }
  }

  // MARK: Private

  @State private var filter: AuditableEntity?

  /// Whether the list should be shown (determines scroll mode)
  private var showList: Bool {
    !isLoading && !filteredEntries.isEmpty
  }

  private var filteredEntries: [AuditEntry] {
    guard let filter else { return entries }
    return entries.filter { $0.entityType == filter }
  }

  private var filterPicker: some View {
    Picker("Filter", selection: $filter) {
      Text("All").tag(nil as AuditableEntity?)
      ForEach(AuditableEntity.allCases, id: \.self) { entity in
        Text(entity.displayName).tag(entity as AuditableEntity?)
      }
    }
    .pickerStyle(.segmented)
    .padding(.horizontal, DS.Spacing.md)
  }

  private var loadingState: some View {
    VStack(spacing: DS.Spacing.md) {
      ProgressView()
      Text("Loading...")
        .font(DS.Typography.caption)
        .foregroundColor(DS.Colors.Text.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var emptyState: some View {
    VStack(spacing: DS.Spacing.md) {
      Image(systemName: "trash")
        .font(.system(size: 48))
        .foregroundColor(DS.Colors.Text.tertiary)
        .accessibilityHidden(true)
      Text("No deleted items")
        .font(DS.Typography.headline)
        .foregroundColor(DS.Colors.Text.secondary)
      Text("Items you delete will appear here")
        .font(DS.Typography.caption)
        .foregroundColor(DS.Colors.Text.tertiary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var groupedList: some View {
    let grouped = Dictionary(grouping: filteredEntries) { entry in
      Calendar.current.startOfDay(for: entry.changedAt)
    }
    let sortedDates = grouped.keys.sorted(by: >)

    return ForEach(sortedDates, id: \.self) { date in
      Section(header: Text(date.formatted(date: .abbreviated, time: .omitted))) {
        ForEach(grouped[date] ?? [], id: \.id) { entry in
          RecentlyDeletedRow(entry: entry) { }
        }
      }
    }
  }
}

// MARK: - Previews

#Preview("Empty State") {
  NavigationStack {
    RecentlyDeletedPreview(entries: [], isLoading: false)
  }
}

#Preview("Loading State") {
  NavigationStack {
    RecentlyDeletedPreview(entries: [], isLoading: true)
  }
}

#Preview("With Deleted Items") {
  NavigationStack {
    RecentlyDeletedPreview(entries: AuditEntry.sampleDeleted, isLoading: false)
  }
}

#Preview("Multiple Entity Types") {
  let entries: [AuditEntry] = [
    .mockDelete,
    .mockDeletedTask,
    .mockDeletedProperty,
    AuditEntry(
      id: UUID(),
      action: .delete,
      changedAt: Date().addingTimeInterval(-3600),
      changedBy: PreviewDataFactory.aliceID,
      entityType: .activity,
      entityId: UUID(),
      summary: "Deleted",
      oldRow: ["title": AnyCodable("Client follow-up call")],
      newRow: nil
    )
  ]

  NavigationStack {
    RecentlyDeletedPreview(entries: entries, isLoading: false)
  }
}
