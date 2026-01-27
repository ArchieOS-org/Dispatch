//
// MARK: - RecentlyDeletedView
//
// Shows recently deleted items with restore capability.
//

import Supabase
import SwiftData
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

  @Environment(\.modelContext) private var modelContext

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
    #if DEBUG
    debugLog.log("[AUDIT] RecentlyDeletedView.loadDeletedItems started", category: .sync)
    #endif

    isLoading = true
    error = nil
    do {
      entries = try await AuditSyncHandler(supabase: supabase).fetchRecentlyDeleted()

      #if DEBUG
      debugLog.log(
        "[AUDIT] RecentlyDeletedView.loadDeletedItems complete: entries=\(entries.count)",
        category: .sync
      )
      if entries.isEmpty {
        debugLog.log("[AUDIT] RecentlyDeletedView: No deleted items returned", category: .sync)
      }
      #endif
    } catch {
      #if DEBUG
      debugLog.error("[AUDIT] RecentlyDeletedView.loadDeletedItems FAILED", error: error)
      #endif
      self.error = error
    }
    isLoading = false
  }

  private func restoreEntry(_ entry: AuditEntry) async {
    #if DEBUG
    debugLog.log(
      "[AUDIT] RecentlyDeletedView.restoreEntry started: entityType=\(entry.entityType.rawValue), entityId=\(entry.entityId)",
      category: .sync
    )
    #endif

    do {
      let restoredId = try await AuditSyncHandler(supabase: supabase)
        .restoreEntity(entry.entityType, entityId: entry.entityId)

      #if DEBUG
      debugLog.log(
        "[AUDIT] RecentlyDeletedView.restoreEntry SUCCESS: restoredId=\(restoredId)",
        category: .sync
      )
      #endif

      // CRITICAL: Fetch and insert restored entity into local SwiftData immediately.
      // Without this, the entity only exists on server until next sync.
      // The reconciliation pass would then fetch it, but with timestamp precision issues
      // that can cause a sync loop (server timestamp >= lastSyncTime -> re-fetched each sync).
      // By inserting it here with markSynced(), we ensure proper sync state.
      try await fetchAndInsertRestoredEntity(entityType: entry.entityType, entityId: restoredId)

      // Remove from list
      Task { @MainActor in
        entries.removeAll { $0.id == entry.id }
        restoredEntityNavigation = RestoredNavTarget(type: entry.entityType, entityId: restoredId)
      }
    } catch {
      #if DEBUG
      debugLog.error("[AUDIT] RecentlyDeletedView.restoreEntry FAILED", error: error)
      #endif
      Task { @MainActor in
        self.error = error
      }
    }
  }

  /// Fetches the restored entity from Supabase and inserts it into local SwiftData.
  /// This prevents sync loops by ensuring the entity exists locally with correct sync state
  /// before the next sync cycle runs.
  private func fetchAndInsertRestoredEntity(entityType: AuditableEntity, entityId: UUID) async throws {
    switch entityType {
    case .task:
      let dto: TaskDTO = try await supabase
        .from("tasks")
        .select()
        .eq("id", value: entityId.uuidString)
        .single()
        .execute()
        .value
      let task = dto.toModel()
      task.markSynced()
      modelContext.insert(task)
      #if DEBUG
      debugLog.log(
        "[AUDIT] Inserted restored task into SwiftData: \(entityId) - \(task.title)",
        category: .sync
      )
      #endif

    case .listing:
      let dto: ListingDTO = try await supabase
        .from("listings")
        .select()
        .eq("id", value: entityId.uuidString)
        .single()
        .execute()
        .value
      let listing = dto.toModel()
      listing.markSynced()
      modelContext.insert(listing)
      #if DEBUG
      debugLog.log(
        "[AUDIT] Inserted restored listing into SwiftData: \(entityId) - \(listing.address)",
        category: .sync
      )
      #endif

    case .activity:
      let dto: ActivityDTO = try await supabase
        .from("activities")
        .select()
        .eq("id", value: entityId.uuidString)
        .single()
        .execute()
        .value
      let activity = dto.toModel()
      activity.markSynced()
      modelContext.insert(activity)
      #if DEBUG
      debugLog.log(
        "[AUDIT] Inserted restored activity into SwiftData: \(entityId) - \(activity.title)",
        category: .sync
      )
      #endif

    case .property:
      let dto: PropertyDTO = try await supabase
        .from("properties")
        .select()
        .eq("id", value: entityId.uuidString)
        .single()
        .execute()
        .value
      let property = dto.toModel()
      property.markSynced()
      modelContext.insert(property)
      #if DEBUG
      debugLog.log(
        "[AUDIT] Inserted restored property into SwiftData: \(entityId)",
        category: .sync
      )
      #endif

    case .user, .taskAssignee, .activityAssignee, .note:
      // These entity types are either not directly restorable or are handled differently
      #if DEBUG
      debugLog.log(
        "[AUDIT] Entity type \(entityType.rawValue) does not require local insertion after restore",
        category: .sync
      )
      #endif
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
    .mockDeletedActivity
  ]

  NavigationStack {
    RecentlyDeletedPreview(entries: entries, isLoading: false)
  }
}
