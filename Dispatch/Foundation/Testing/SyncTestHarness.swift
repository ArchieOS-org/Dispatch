//
//  SyncTestHarness.swift
//  Dispatch
//
//  Created for Phase 1.3: Testing Infrastructure
//  Debug console UI for testing sync operations
//

import SwiftData
import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - SyncTestHarness

/// Debug console for testing SyncManager operations
/// Only available in DEBUG builds
struct SyncTestHarness: View {

  // MARK: Internal

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          statusSection
          countsSection
          actionsSection
          realtimeDiagnosticsSection
          debugLogSection
        }
        .padding()
      }
      .navigationTitle("Sync Test Harness")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
        .toolbar {
          #if os(iOS)
          ToolbarItem(placement: .topBarTrailing) {
            Button("Refresh") {
              Task { await refreshCounts() }
            }
            .disabled(isLoading)
          }
          #else
          ToolbarItem(placement: .automatic) {
            Button("Refresh") {
              Task { await refreshCounts() }
            }
            .disabled(isLoading)
          }
          #endif
        }
        .onAppear {
          Task { await refreshCounts() }
        }
    }
  }

  // MARK: Private

  @EnvironmentObject private var syncManager: SyncManager
  @Environment(\.modelContext) private var modelContext

  #if DEBUG
  @StateObject private var debugLogger = DebugLogger.shared
  #endif

  @State private var logMessages = [LogEntry]()
  @State private var supabaseCounts = EntityCounts(tasks: 0, activities: 0, listings: 0, users: 0)
  @State private var localCounts = EntityCounts(tasks: 0, activities: 0, listings: 0, users: 0)
  @State private var isLoading = false
  @State private var selectedLogFilter: String? = nil
  @State private var showSystemLogs = true

  private var statusInfo: (Color, String) {
    switch syncManager.syncStatus {
    case .idle: (.gray, "IDLE")
    case .syncing: (.blue, "SYNCING")
    case .ok: (.green, "OK")
    case .error: (.red, "ERROR")
    case .circuitBreakerOpen(let seconds): (.orange, "PAUSED (\(seconds)s)")
    }
  }

  private var statusSection: some View {
    GroupBox("Sync Status") {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Status:")
          Spacer()
          statusBadge
        }

        HStack {
          Text("Is Syncing:")
          Spacer()
          Text(syncManager.isSyncing ? "Yes" : "No")
            .foregroundColor(syncManager.isSyncing ? .orange : .secondary)
        }

        HStack {
          Text("Last Sync:")
          Spacer()
          if let lastSync = syncManager.lastSyncTime {
            Text(lastSync, style: .time)
          } else {
            Text("Never")
              .foregroundColor(.secondary)
          }
        }

        if let error = syncManager.syncError {
          HStack(alignment: .top) {
            Text("Error:")
            Spacer()
            Text(error.localizedDescription)
              .foregroundColor(.red)
              .font(.caption)
              .multilineTextAlignment(.trailing)
          }
        }
      }
      .font(.system(.body, design: .monospaced))
    }
  }

  @ViewBuilder
  private var statusBadge: some View {
    let (color, text) = statusInfo
    Text(text)
      .font(.caption.bold())
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(color.opacity(0.2))
      .foregroundColor(color)
      .clipShape(Capsule())
  }

  private var countsSection: some View {
    GroupBox("Entity Counts") {
      VStack(spacing: 12) {
        HStack {
          Text("")
            .frame(width: 80, alignment: .leading)
          Text("Local")
            .frame(maxWidth: .infinity)
            .font(.caption.bold())
          Text("Supabase")
            .frame(maxWidth: .infinity)
            .font(.caption.bold())
          Text("Match")
            .frame(width: 50)
            .font(.caption.bold())
        }

        countRow("Tasks", local: localCounts.tasks, remote: supabaseCounts.tasks)
        countRow("Activities", local: localCounts.activities, remote: supabaseCounts.activities)
        countRow("Listings", local: localCounts.listings, remote: supabaseCounts.listings)
        countRow("Users", local: localCounts.users, remote: supabaseCounts.users)
      }
      .font(.system(.body, design: .monospaced))
    }
  }

  private var actionsSection: some View {
    GroupBox("Test Actions") {
      VStack(spacing: 12) {
        // Sync Controls
        HStack(spacing: 12) {
          Button(action: { Task { await triggerSync() } }) {
            Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .disabled(isLoading || syncManager.isSyncing)

          Button(action: { Task { await triggerFullSync() } }) {
            Label("Full Sync", systemImage: "arrow.triangle.2.circlepath.circle.fill")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .tint(.orange)
          .disabled(isLoading || syncManager.isSyncing)
        }

        HStack(spacing: 12) {
          Button(action: { Task { await triggerDebouncedSync() } }) {
            Label("Debounced", systemImage: "timer")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .disabled(isLoading)

          Button(action: { resetSyncState() }) {
            Label("Reset State", systemImage: "clock.arrow.circlepath")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .tint(.gray)
        }

        HStack(spacing: 12) {
          Button(action: { Task { await resetFailedEntities() } }) {
            Label("Reset Failed", systemImage: "arrow.counterclockwise.circle")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .tint(.red)
          .disabled(isLoading || syncManager.isSyncing)
        }

        // Data Creation
        HStack(spacing: 12) {
          Button(action: { createTestTask() }) {
            Label("+ Task", systemImage: "checkmark.circle")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .tint(.blue)

          Button(action: { createTestActivity() }) {
            Label("+ Activity", systemImage: "calendar")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .tint(.purple)

          Button(action: { createTestListing() }) {
            Label("+ Listing", systemImage: "house")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .tint(.orange)
        }

        // Batch Operations
        HStack(spacing: 12) {
          Button(action: { createTestDataset() }) {
            Label("Create Dataset", systemImage: "plus.square.on.square")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .tint(.green)

          Button(role: .destructive, action: { Task { await cleanupTestData() } }) {
            Label("Cleanup", systemImage: "trash")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
        }

        // Realtime Controls
        HStack(spacing: 12) {
          Button(action: { Task { await startListening() } }) {
            Label("Start Realtime", systemImage: "antenna.radiowaves.left.and.right")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .tint(.cyan)

          Button(action: { Task { await stopListening() } }) {
            Label("Stop Realtime", systemImage: "antenna.radiowaves.left.and.right.slash")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
        }
      }
    }
  }

  private var realtimeDiagnosticsSection: some View {
    GroupBox("Realtime Diagnostics") {
      VStack(spacing: 12) {
        HStack(spacing: 12) {
          Button(action: { Task { await checkRealtimeStatus() } }) {
            Label("Check Status", systemImage: "stethoscope")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .tint(.purple)

          Button(action: { Task { await forceReconnect() } }) {
            Label("Reconnect", systemImage: "arrow.clockwise.circle")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .tint(.orange)
        }

        Text("Check Xcode console for detailed realtime logs")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
  }

  #if DEBUG
  private var debugLogSection: some View {
    GroupBox("Debug Log (\(filteredLogs.count))") {
      VStack(alignment: .leading, spacing: 8) {
        // Filter buttons
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            FilterButton(title: "All", isSelected: selectedLogFilter == nil) {
              selectedLogFilter = nil
            }
            ForEach(DebugLogger.Category.allCases, id: \.self) { category in
              FilterButton(title: category.emoji, isSelected: selectedLogFilter == category.rawValue) {
                selectedLogFilter = category.rawValue
              }
            }
          }
        }

        Divider()

        // Log entries
        if filteredLogs.isEmpty {
          Text("No log entries")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
        } else {
          ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
              ForEach(filteredLogs.suffix(100).reversed()) { entry in
                DebugLogEntryRow(entry: entry)
              }
            }
          }
          .frame(maxHeight: 300)
        }

        // Controls
        HStack {
          Button("Clear") {
            debugLogger.clearLogs()
          }
          .font(.caption)

          Spacer()

          Button("Copy All") {
            #if os(iOS)
            UIPasteboard.general.string = debugLogger.exportLogs()
            #elseif os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(debugLogger.exportLogs(), forType: .string)
            #endif
          }
          .font(.caption)
        }
        .padding(.top, 8)
      }
    }
  }

  private var filteredLogs: [DebugLogEntry] {
    guard let filter = selectedLogFilter else { return debugLogger.logs }
    return debugLogger.logs.filter { $0.category.rawValue == filter }
  }
  #else
  private var debugLogSection: some View {
    EmptyView()
  }
  #endif

  private func countRow(_ label: String, local: Int, remote: Int) -> some View {
    HStack {
      Text(label)
        .frame(width: 80, alignment: .leading)
      Text("\(local)")
        .frame(maxWidth: .infinity)
      Text("\(remote)")
        .frame(maxWidth: .infinity)
      Image(systemName: local == remote ? "checkmark.circle.fill" : "xmark.circle.fill")
        .foregroundColor(local == remote ? .green : .red)
        .frame(width: 50)
    }
  }

  private func log(_ message: String, isError: Bool = false) {
    logMessages.append(LogEntry(message: message, isError: isError))
    #if DEBUG
    debugLog.log(message, category: isError ? .error : .sync)
    #endif
  }

  private func refreshCounts() async {
    isLoading = true
    defer { isLoading = false }

    log("Refreshing counts...")

    // Fetch local counts
    do {
      let taskDescriptor = FetchDescriptor<TaskItem>()
      let activityDescriptor = FetchDescriptor<Activity>()
      let listingDescriptor = FetchDescriptor<Listing>()
      let userDescriptor = FetchDescriptor<User>()

      localCounts = EntityCounts(
        tasks: try modelContext.fetchCount(taskDescriptor),
        activities: try modelContext.fetchCount(activityDescriptor),
        listings: try modelContext.fetchCount(listingDescriptor),
        users: try modelContext.fetchCount(userDescriptor)
      )
    } catch {
      log("Failed to fetch local counts: \(error.localizedDescription)", isError: true)
    }

    // Fetch Supabase counts
    supabaseCounts = await SupabaseTestHelpers.fetchCounts()

    log(
      "Counts refreshed - Local: \(localCounts.tasks)/\(localCounts.activities)/\(localCounts.listings)/\(localCounts.users), Supabase: \(supabaseCounts.tasks)/\(supabaseCounts.activities)/\(supabaseCounts.listings)/\(supabaseCounts.users)"
    )
  }

  private func triggerSync() async {
    log("Triggering immediate sync...")
    await syncManager.sync()
    log("Sync completed")
    await refreshCounts()
  }

  private func triggerDebouncedSync() async {
    log("Triggering debounced sync (500ms)...")
    syncManager.requestSync()
    // Wait for debounce + sync
    try? await Task.sleep(nanoseconds: 1_000_000_000)
    await refreshCounts()
  }

  private func triggerFullSync() async {
    log("Triggering FULL sync with orphan reconciliation...")
    await syncManager.fullSync()
    log("Full sync completed (orphans removed if any)")
    await refreshCounts()
  }

  private func resetSyncState() {
    log("Resetting sync state (lastSyncTime = nil)...")
    syncManager.resetLastSyncTime()
    log("Next sync will run full reconciliation")
  }

  private func resetFailedEntities() async {
    log("Resetting all failed entities (retryCount = 0, syncState = pending)...")
    await syncManager.resetFailedEntities()
    log("Failed entities reset and sync triggered")
    await refreshCounts()
  }

  private func createTestTask() {
    let index = localCounts.tasks + 1
    let task = TestDataFactory.createTestTask(context: modelContext, index: index)
    log("Created test task: \(task.title) (id: \(task.id.uuidString.prefix(8))...)")
    // Trigger debounced sync to upload new task to Supabase
    syncManager.requestSync()
    Task { await refreshCounts() }
  }

  private func createTestActivity() {
    let index = localCounts.activities + 1
    let activity = TestDataFactory.createTestActivity(context: modelContext, index: index)
    log("Created test activity: \(activity.title) (id: \(activity.id.uuidString.prefix(8))...)")
    // Trigger debounced sync to upload new activity to Supabase
    syncManager.requestSync()
    Task { await refreshCounts() }
  }

  private func createTestListing() {
    let index = localCounts.listings + 1
    let listing = TestDataFactory.createTestListing(context: modelContext, index: index)
    log("Created test listing: \(listing.address) (id: \(listing.id.uuidString.prefix(8))...)")
    // Trigger debounced sync to upload new listing to Supabase
    syncManager.requestSync()
    Task { await refreshCounts() }
  }

  private func createTestDataset() {
    log("Creating test dataset...")
    TestDataFactory.createTestDataset(context: modelContext)
    log("Test dataset created")
    // Trigger debounced sync to upload new dataset to Supabase
    syncManager.requestSync()
    Task { await refreshCounts() }
  }

  private func cleanupTestData() async {
    log("Cleaning up test data from Supabase AND local SwiftData...")

    // 1. Delete from Supabase first
    await SupabaseTestHelpers.deleteAllTestData()
    log("Supabase test data deleted")

    // 2. Delete matching test data from local SwiftData
    // Test UUIDs follow pattern: 00000000-0000-0000-{type}-{index}
    // Types: 0001=user, 0002=task, 0003=activity, 0004=listing
    do {
      var deletedCounts = (tasks: 0, activities: 0, listings: 0, users: 0)

      // Delete test tasks (type = 0002)
      let taskDescriptor = FetchDescriptor<TaskItem>()
      let allTasks = try modelContext.fetch(taskDescriptor)
      for task in allTasks where task.id.uuidString.lowercased().hasPrefix("00000000-0000-0000-0002-") {
        modelContext.delete(task)
        deletedCounts.tasks += 1
      }

      // Delete test activities (type = 0003)
      let activityDescriptor = FetchDescriptor<Activity>()
      let allActivities = try modelContext.fetch(activityDescriptor)
      for activity in allActivities where activity.id.uuidString.lowercased().hasPrefix("00000000-0000-0000-0003-") {
        modelContext.delete(activity)
        deletedCounts.activities += 1
      }

      // Delete test listings (type = 0004)
      let listingDescriptor = FetchDescriptor<Listing>()
      let allListings = try modelContext.fetch(listingDescriptor)
      for listing in allListings where listing.id.uuidString.lowercased().hasPrefix("00000000-0000-0000-0004-") {
        modelContext.delete(listing)
        deletedCounts.listings += 1
      }

      // Delete test users (type = 0001) - optional, but included for completeness
      let userDescriptor = FetchDescriptor<User>()
      let allUsers = try modelContext.fetch(userDescriptor)
      for user in allUsers where user.id.uuidString.lowercased().hasPrefix("00000000-0000-0000-0001-") {
        modelContext.delete(user)
        deletedCounts.users += 1
      }

      // Save deletions
      try modelContext.save()

      log(
        "Local test data deleted: \(deletedCounts.tasks) tasks, \(deletedCounts.activities) activities, \(deletedCounts.listings) listings, \(deletedCounts.users) users"
      )
      #if DEBUG
      debugLog.log(
        "Cleanup deleted local: tasks=\(deletedCounts.tasks), activities=\(deletedCounts.activities), listings=\(deletedCounts.listings), users=\(deletedCounts.users)",
        category: .sync
      )
      #endif
    } catch {
      log("Failed to delete local test data: \(error.localizedDescription)", isError: true)
    }

    log("Cleanup complete (both Supabase and local)")
    await refreshCounts()
  }

  private func startListening() async {
    log("Starting realtime listener...")
    await syncManager.startListening()
    log("Realtime listener started")
  }

  private func stopListening() async {
    log("Stopping realtime listener...")
    await syncManager.stopListening()
    log("Realtime listener stopped")
  }

  private func checkRealtimeStatus() async {
    #if DEBUG
    debugLog.log("=== REALTIME STATUS CHECK ===", category: .realtime)
    debugLog.log("SyncManager.currentUserID: \(syncManager.currentUserID?.uuidString ?? "nil")", category: .realtime)
    debugLog.log("Check Xcode console for full status", category: .realtime)
    #endif
    log("Realtime status check logged to console")
  }

  private func forceReconnect() async {
    #if DEBUG
    debugLog.log("=== FORCE RECONNECT ===", category: .realtime)
    #endif
    log("Force reconnecting...")
    await syncManager.stopListening()
    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
    await syncManager.startListening()
    log("Reconnect complete")
  }
}

// MARK: - FilterButton

private struct FilterButton: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
        .foregroundColor(isSelected ? .white : .primary)
        .cornerRadius(DS.Spacing.radiusMedium)
    }
  }
}

// MARK: - Debug Log Entry Row

#if DEBUG
private struct DebugLogEntryRow: View {
  let entry: DebugLogEntry

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Text(entry.timestamp, style: .time)
        .font(.system(size: 10, design: .monospaced))
        .foregroundColor(.secondary)
        .frame(width: 65, alignment: .leading)

      Text(entry.category.emoji)
        .font(.caption)

      Text(entry.message)
        .font(.system(size: 11, design: .monospaced))
        .foregroundColor(entry.isError ? .red : .primary)
        .lineLimit(3)
    }
    .padding(.vertical, 2)
  }
}
#endif

// MARK: - LogEntry

private struct LogEntry: Identifiable {
  let id = UUID()
  let timestamp = Date()
  let message: String
  let isError: Bool
}

// MARK: - Preview

#Preview {
  SyncTestHarness()
    .environmentObject(SyncManager.shared)
    .modelContainer(for: [User.self, TaskItem.self, Activity.self, Listing.self])
}
