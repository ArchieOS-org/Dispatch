// MARK: - StagedListingRow

/// Local row for staged listings: minimal, no icons, no chevron, trailing capsule
private struct StagedListingRow: View {

  // MARK: Internal

  let listing: Listing

  var body: some View {
    HStack(spacing: DS.Spacing.md) {
      VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        Text(listing.address)
          .font(DS.Typography.body)
          .foregroundStyle(.primary)

        let colors = typeTagColors
        Text(listing.listingType.rawValue.capitalized)
          .font(DS.Typography.caption)
          .foregroundStyle(colors.fg)
      }

      Spacer(minLength: 0)
    }
    .padding(.vertical, DS.Spacing.listRowPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
  }

  // MARK: Private

  private var typeTagColors: (fg: Color, bg: Color) {
    let palette: [Color] = [.blue, .green, .orange, .purple, .teal, .pink]
    let key = listing.listingType.rawValue.lowercased()
    let idx = Int(key.hashValue.magnitude) % palette.count
    let base = palette[idx]
    return (fg: base, bg: base.opacity(0.14))
  }

}

//
//  StagedListingsView.swift
//  Dispatch
//
//  Filtered listings view by stage with query-level filtering.
//

import SwiftData
import SwiftUI

// MARK: - ListingGroup

/// A group of listings belonging to a single owner (reused pattern)
private struct ListingGroup: Identifiable {
  let owner: User?
  let listings: [Listing]

  var id: String {
    owner?.id.uuidString ?? "unknown"
  }
}

// MARK: - StagedListingsView

/// Displays listings filtered by a specific stage.
/// Uses query-level filtering for performance.
struct StagedListingsView: View {

  // MARK: Internal

  let stage: ListingStage

  var body: some View {
    StandardScreen(title: stage.displayName, layout: .column, scroll: .automatic) {
      if groupedByOwner.isEmpty {
        // Caller handles empty state
        ContentUnavailableView {
          Label("No \(stage.displayName) Listings", systemImage: stage.icon)
        } description: {
          Text("Listings in this stage will appear here")
        }
      } else {
        StandardGroupedList(
          groupedByOwner,
          items: { $0.listings },
          header: { group in
            SectionHeader(group.owner?.name ?? "Unknown Owner")
          },
          row: { _, listing in
            ListRowLink(value: AppRoute.listing(listing.id)) {
              StagedListingRow(listing: listing)
            }
          }
        )
        .pullToSearch() // Required: sensor is internal, modifier enables mechanism
      }
    }
  }

  // MARK: Private

  /// Query-level filtering - database does the work, not UI
  /// Using in-memory filter as fallback since SwiftData #Predicate
  /// can be picky with enum comparisons in dynamic init
  @Query(sort: \Listing.address)
  private var allListingsRaw: [Listing]

  @Query private var users: [User]

  @EnvironmentObject private var syncManager: SyncManager

  /// Filter to this stage only (excluding deleted)
  private var filteredListings: [Listing] {
    allListingsRaw.filter {
      $0.status != .deleted && $0.stage == stage
    }
  }

  /// Pre-computed user lookup dictionary for O(1) access
  private var userCache: [UUID: User] {
    Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
  }

  /// Listings grouped by owner, sorted by owner name
  private var groupedByOwner: [ListingGroup] {
    let grouped = Dictionary(grouping: filteredListings) { $0.ownedBy }

    let groups = grouped.map { key, value in
      ListingGroup(owner: userCache[key], listings: value)
    }

    return groups.sorted { a, b in
      let nameA = a.owner?.name ?? "~"
      let nameB = b.owner?.name ?? "~"
      return nameA < nameB
    }
  }

}

// MARK: - StagedListingsPreviewData

private enum StagedListingsPreviewData {
  @MainActor
  static func seededContainer() -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Listing.self, User.self, configurations: config)
    let context = ModelContext(container)
    PreviewDataFactory.seed(context)

    // Preview-only: ensure some seeded listings appear in the Live stage
    let descriptor = FetchDescriptor<Listing>(sortBy: [SortDescriptor(\Listing.address)])
    if let listings = try? context.fetch(descriptor) {
      for listing in listings.prefix(5) {
        listing.stage = .live
      }
    }
    try? context.save()

    return container
  }
}

#Preview("Staged Listings - Live (Seeded)") {
  NavigationStack {
    StagedListingsView(stage: .live)
  }
  .modelContainer(StagedListingsPreviewData.seededContainer())
  .environmentObject(SyncManager(mode: .preview))
  .environmentObject(LensState())
}

#Preview("Staged Listings - Live") {
  NavigationStack {
    StagedListingsView(stage: .live)
  }
  .modelContainer(for: [Listing.self, User.self], inMemory: true)
  .environmentObject(SyncManager(mode: .preview))
  .environmentObject(LensState())
}

#Preview("Staged Listings - Pending") {
  NavigationStack {
    StagedListingsView(stage: .pending)
  }
  .modelContainer(for: [Listing.self, User.self], inMemory: true)
  .environmentObject(SyncManager(mode: .preview))
  .environmentObject(LensState())
}
