//
//  StagedListingsView.swift
//  Dispatch
//
//  Filtered listings view by stage with query-level filtering.
//

import SwiftUI
import SwiftData

/// A group of listings belonging to a single owner (reused pattern)
private struct ListingGroup: Identifiable {
    var id: String { owner?.id.uuidString ?? "unknown" }
    let owner: User?
    let listings: [Listing]
}

/// Displays listings filtered by a specific stage.
/// Uses query-level filtering for performance.
struct StagedListingsView: View {
    let stage: ListingStage

    // Query-level filtering - database does the work, not UI
    // Using in-memory filter as fallback since SwiftData #Predicate
    // can be picky with enum comparisons in dynamic init
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

        let groups = grouped.map { (key, value) in
            ListingGroup(owner: userCache[key], listings: value)
        }

        return groups.sorted { a, b in
            let nameA = a.owner?.name ?? "~"
            let nameB = b.owner?.name ?? "~"
            return nameA < nameB
        }
    }

    var body: some View {
        StandardScreen(title: stage.displayName, layout: .column, scroll: .disabled) {
            StandardList(groupedByOwner) { group in
                Section(group.owner?.name ?? "Unknown Owner") {
                    ForEach(group.listings) { listing in
                        NavigationLink(value: listing) {
                            ListingRow(listing: listing, owner: group.owner)
                        }
                    }
                }
            } emptyContent: {
                ContentUnavailableView {
                    Label("No \(stage.displayName) Listings", systemImage: DS.Icons.Stage.icon(for: stage))
                } description: {
                    Text("Listings in this stage will appear here")
                }
            }
            .pullToSearch()
        }
    }
}

// MARK: - Preview

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
