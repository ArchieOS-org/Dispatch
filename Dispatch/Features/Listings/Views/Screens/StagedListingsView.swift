// MARK: - StagedListingRow

/// Local row for staged listings: minimal, no icons, no chevron, trailing capsule
private struct StagedListingRow: View {

  // MARK: Internal

  let listing: Listing

  var body: some View {
    HStack(spacing: DS.Spacing.md) {
      if shouldShowProgress {
        ProgressCircle(progress: listing.progress, size: 18)
      }
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

  /// Show progress circle for stages other than live, done, sold
  private var shouldShowProgress: Bool {
    switch listing.stage {
    case .live, .done, .sold:
      false
    default:
      true
    }
  }

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
      }
    }
    // Memoization: recompute grouped listings when dependencies change
    .onChange(of: allListingsRaw, initial: true) { _, _ in
      updateGroupedByOwner()
    }
    .onChange(of: users) { _, _ in
      updateGroupedByOwner()
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

  /// Memoized computed result - only recalculated when dependencies change
  @State private var groupedByOwner: [ListingGroup] = []

  /// Filter to this stage only (excluding deleted)
  private func computeFilteredListings() -> [Listing] {
    allListingsRaw.filter {
      $0.status != .deleted && $0.stage == stage
    }
  }

  /// Pre-computed user lookup dictionary for O(1) access
  private func computeUserCache() -> [UUID: User] {
    Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
  }

  /// Recomputes grouped listings from current state
  private func updateGroupedByOwner() {
    let filteredListings = computeFilteredListings()
    let userCache = computeUserCache()

    let grouped = Dictionary(grouping: filteredListings) { $0.ownedBy }

    let groups = grouped.map { key, value in
      ListingGroup(owner: userCache[key], listings: value)
    }

    groupedByOwner = groups.sorted { a, b in
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

    // Preview-only: distribute seeded listings across *all* stages for previews
    let descriptor = FetchDescriptor<Listing>(sortBy: [SortDescriptor(\Listing.address)])
    let stages = ListingStage.allCases
    if let listings = try? context.fetch(descriptor), !stages.isEmpty {
      for (idx, listing) in listings.enumerated() {
        listing.stage = stages[idx % stages.count]
      }
    }
    try? context.save()

    return container
  }
}

// MARK: - StagedListingsView_Previews

struct StagedListingsView_Previews: PreviewProvider {
  static var previews: some View {
    ForEach(ListingStage.allCases, id: \.self) { stage in
      NavigationStack {
        StagedListingsView(stage: stage)
      }
      .modelContainer(StagedListingsPreviewData.seededContainer())
      .environmentObject(SyncManager(mode: .preview))
      .environmentObject(LensState())
      .previewDisplayName("Staged Listings - \(stage.displayName)")
    }
  }
}
