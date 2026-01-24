//
//  HistorySection.swift
//  Dispatch
//
//  Collapsible history section for entity detail views.
//  Shows audit history with loading/empty/error states.
//

import Supabase
import SwiftUI

// MARK: - HistorySection

struct HistorySection: View {

  // MARK: Internal

  let entityType: AuditableEntity
  let entityId: UUID
  let currentUserId: UUID
  let userLookup: (UUID) -> User?
  let supabase: SupabaseClient
  let onRestore: ((AuditEntry) async throws -> Void)?

  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      content
    } label: {
      sectionHeader
    }
    // FIX 2C: Use .task(id:) to prevent re-firing on unrelated state changes
    .task(id: entityId) { await loadHistory() }
    .overlay(alignment: .bottom) {
      if let message = restoreToastMessage {
        Text(message)
          .font(DS.Typography.caption)
          .padding(.horizontal, DS.Spacing.md)
          .padding(.vertical, DS.Spacing.sm)
          .background(DS.Colors.Background.secondary)
          .cornerRadius(DS.Spacing.radiusMedium)
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .animation(.easeInOut, value: restoreToastMessage)
      }
    }
  }

  // MARK: Private

  @State private var entries: [AuditEntry] = []
  @State private var isLoading = true
  @State private var error: Error?
  @State private var isExpanded = true
  @State private var showAllHistory = false
  @State private var restoreToastMessage: String?

  private var displayedEntries: [AuditEntry] {
    showAllHistory ? entries : Array(entries.prefix(5))
  }

  private var sectionHeader: some View {
    HStack {
      Text("History")
        .font(DS.Typography.headline)
        .foregroundColor(DS.Colors.Text.primary)
      Text("(\(entries.count))")
        .font(DS.Typography.bodySecondary)
        .foregroundColor(DS.Colors.Text.secondary)
      Spacer()
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("History, \(entries.count)")
  }

  @ViewBuilder
  private var content: some View {
    if isLoading {
      loadingState
    } else if let error {
      errorState(error)
    } else if entries.isEmpty {
      emptyState
    } else {
      historyList
    }
  }

  private var loadingState: some View {
    VStack(spacing: DS.Spacing.sm) {
      ProgressView()
      Text("Loading history...")
        .font(DS.Typography.caption)
        .foregroundColor(DS.Colors.Text.secondary)
    }
    .padding(.vertical, DS.Spacing.lg)
  }

  private var emptyState: some View {
    VStack(spacing: DS.Spacing.sm) {
      Image(systemName: "clock")
        .font(.system(size: 32))
        .foregroundColor(DS.Colors.Text.tertiary)
      Text("No history available")
        .font(DS.Typography.body)
        .foregroundColor(DS.Colors.Text.secondary)
    }
    .padding(.vertical, DS.Spacing.lg)
  }

  private var historyList: some View {
    VStack(spacing: 0) {
      ForEach(displayedEntries, id: \.id) { entry in
        if entry.action == .update {
          NavigationLink(destination: HistoryDetailView(entry: entry, userLookup: userLookup)) {
            HistoryEntryRow(
              entry: entry,
              currentUserId: currentUserId,
              userLookup: userLookup,
              onRestore: nil
            )
          }
          .buttonStyle(.plain)
        } else if entry.action == .delete, onRestore != nil {
          HistoryEntryRow(
            entry: entry,
            currentUserId: currentUserId,
            userLookup: userLookup,
            onRestore: { await restoreEntry(entry) }
          )
        } else {
          HistoryEntryRow(
            entry: entry,
            currentUserId: currentUserId,
            userLookup: userLookup,
            onRestore: nil
          )
        }
        if entry.id != displayedEntries.last?.id {
          Divider()
        }
      }

      if entries.count > 5, !showAllHistory {
        Button {
          withAnimation { showAllHistory = true }
        } label: {
          Text("Show all \(entries.count) events")
            .font(DS.Typography.caption)
            .foregroundColor(DS.Colors.accent)
        }
        .padding(.top, DS.Spacing.sm)
      }
    }
  }

  private func errorState(_: Error) -> some View {
    VStack(spacing: DS.Spacing.sm) {
      Image(systemName: DS.Icons.Alert.error)
        .font(.system(size: 32))
        .foregroundColor(DS.Colors.destructive)
      Text("Failed to load history")
        .font(DS.Typography.body)
        .foregroundColor(DS.Colors.Text.secondary)
      Button("Retry") {
        Task { await loadHistory() }
      }
      .buttonStyle(.bordered)
    }
    .padding(.vertical, DS.Spacing.lg)
  }

  private func loadHistory() async {
    #if DEBUG
    debugLog.log(
      "[AUDIT] HistorySection.loadHistory started: entityType=\(entityType.rawValue), entityId=\(entityId)",
      category: .sync
    )
    #endif

    isLoading = true
    error = nil
    do {
      // Use combined history to include related entries (assignments for tasks/activities, notes for listings/properties)
      entries = try await AuditSyncHandler(supabase: supabase).fetchCombinedHistory(
        for: entityType,
        entityId: entityId
      )

      #if DEBUG
      debugLog.log(
        "[AUDIT] HistorySection.loadHistory complete: entries=\(entries.count)",
        category: .sync
      )
      if entries.isEmpty {
        debugLog.log("[AUDIT] HistorySection: No history entries returned for this entity", category: .sync)
      }
      #endif
    } catch {
      #if DEBUG
      debugLog.error("[AUDIT] HistorySection.loadHistory FAILED", error: error)
      #endif
      self.error = error
    }
    isLoading = false
  }

  private func restoreEntry(_ entry: AuditEntry) async {
    guard let onRestore else {
      #if DEBUG
      debugLog.log("[AUDIT] HistorySection.restoreEntry: onRestore callback is nil", category: .sync)
      #endif
      restoreToastMessage = "Restore unavailable"
      return
    }

    #if DEBUG
    debugLog.log(
      "[AUDIT] HistorySection.restoreEntry started: entityType=\(entry.entityType.rawValue), entityId=\(entry.entityId)",
      category: .sync
    )
    #endif

    do {
      try await onRestore(entry)
      #if DEBUG
      debugLog.log("[AUDIT] HistorySection.restoreEntry SUCCESS", category: .sync)
      #endif
      restoreToastMessage = "\(entityType.displayName) restored successfully"
      await loadHistory()
      // Auto-dismiss toast after 3 seconds
      Task {
        try? await Task.sleep(for: .seconds(3))
        // Defer state mutation to next run loop
        Task { @MainActor in
          restoreToastMessage = nil
        }
      }
    } catch {
      #if DEBUG
      debugLog.error("[AUDIT] HistorySection.restoreEntry FAILED", error: error)
      #endif
      restoreToastMessage = error.localizedDescription
    }
  }
}

// MARK: - HistorySectionPreview

/// A preview-friendly wrapper that displays history with injected mock data.
/// Used to bypass the async loading from Supabase in previews.
private struct HistorySectionPreview: View {

  // MARK: Internal

  let entries: [AuditEntry]
  let isLoading: Bool
  let error: Error?

  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      content
    } label: {
      HStack {
        Text("History")
          .font(DS.Typography.headline)
          .foregroundColor(DS.Colors.Text.primary)
        Text("(\(entries.count))")
          .font(DS.Typography.bodySecondary)
          .foregroundColor(DS.Colors.Text.secondary)
        Spacer()
      }
    }
  }

  // MARK: Private

  @State private var isExpanded = true

  @ViewBuilder
  private var content: some View {
    if isLoading {
      VStack(spacing: DS.Spacing.sm) {
        ProgressView()
        Text("Loading history...")
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.secondary)
      }
      .padding(.vertical, DS.Spacing.lg)
    } else if error != nil {
      VStack(spacing: DS.Spacing.sm) {
        Image(systemName: DS.Icons.Alert.error)
          .font(.system(size: 32))
          .foregroundColor(DS.Colors.destructive)
        Text("Failed to load history")
          .font(DS.Typography.body)
          .foregroundColor(DS.Colors.Text.secondary)
        Button("Retry") { }
          .buttonStyle(.bordered)
      }
      .padding(.vertical, DS.Spacing.lg)
    } else if entries.isEmpty {
      VStack(spacing: DS.Spacing.sm) {
        Image(systemName: "clock")
          .font(.system(size: 32))
          .foregroundColor(DS.Colors.Text.tertiary)
        Text("No history available")
          .font(DS.Typography.body)
          .foregroundColor(DS.Colors.Text.secondary)
      }
      .padding(.vertical, DS.Spacing.lg)
    } else {
      VStack(spacing: 0) {
        ForEach(entries, id: \.id) { entry in
          HistoryEntryRow(
            entry: entry,
            currentUserId: PreviewDataFactory.aliceID,
            userLookup: previewUserLookup,
            onRestore: entry.action == .delete ? { } : nil
          )
          if entry.id != entries.last?.id {
            Divider()
          }
        }
      }
    }
  }

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
}

// MARK: - Previews

#Preview("Loading State") {
  NavigationStack {
    ScrollView {
      HistorySectionPreview(entries: [], isLoading: true, error: nil)
        .padding()
    }
  }
}

#Preview("Empty State") {
  NavigationStack {
    ScrollView {
      HistorySectionPreview(entries: [], isLoading: false, error: nil)
        .padding()
    }
  }
}

#Preview("With History") {
  NavigationStack {
    ScrollView {
      HistorySectionPreview(entries: AuditEntry.sampleHistory, isLoading: false, error: nil)
        .padding()
    }
  }
}

#Preview("Error State") {
  NavigationStack {
    ScrollView {
      HistorySectionPreview(
        entries: [],
        isLoading: false,
        error: NSError(domain: "Preview", code: 0, userInfo: [NSLocalizedDescriptionKey: "Network error"])
      )
      .padding()
    }
  }
}
