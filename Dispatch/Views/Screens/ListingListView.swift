//
//  ListingListView.swift
//  Dispatch
//
//  Main screen for displaying and managing listings
//  Created by Claude on 2025-12-06.
//

import SwiftUI
import SwiftData

/// Main listing list screen with:
/// - Search bar for filtering by address
/// - Grouped by owner
/// - Pull-to-refresh sync
/// - Navigation to listing detail (placeholder)
struct ListingListView: View {
    @Query(sort: \Listing.address)
    private var allListingsRaw: [Listing]

    /// Filter out deleted listings (SwiftData predicates can't compare enums directly)
    private var allListings: [Listing] {
        allListingsRaw.filter { $0.status != .deleted }
    }

    @Query private var users: [User]

    @EnvironmentObject private var syncManager: SyncManager

    @State private var searchText = ""

    // MARK: - Computed Properties

    /// Pre-computed user lookup dictionary for O(1) access
    private var userCache: [UUID: User] {
        Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
    }

    /// Listings filtered by search text
    private var filteredListings: [Listing] {
        if searchText.isEmpty {
            return Array(allListings)
        }
        return allListings.filter {
            $0.address.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Listings grouped by owner, sorted by owner name
    private var groupedByOwner: [(owner: User?, listings: [Listing])] {
        let grouped = Dictionary(grouping: filteredListings) { $0.ownedBy }
        return grouped.map { (userCache[$0.key], $0.value) }
            .sorted { ($0.owner?.name ?? "~") < ($1.owner?.name ?? "~") }
    }

    /// Whether the list is empty (after filtering)
    private var isEmpty: Bool {
        filteredListings.isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if isEmpty {
                    emptyStateView
                } else {
                    listView
                }
            }
            .navigationTitle("Listings")
            .searchable(text: $searchText, prompt: "Search by address")
            .refreshable {
                await syncManager.sync()
            }
            .navigationDestination(for: Listing.self) { listing in
                // Placeholder for listing detail view
                ListingDetailPlaceholder(listing: listing, owner: userCache[listing.ownedBy])
            }
        }
    }

    // MARK: - Subviews

    private var listView: some View {
        List {
            ForEach(groupedByOwner, id: \.owner?.id) { group in
                Section(group.owner?.name ?? "Unknown Owner") {
                    ForEach(group.listings) { listing in
                        NavigationLink(value: listing) {
                            ListingRow(listing: listing, owner: group.owner)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(emptyTitle, systemImage: DS.Icons.Entity.listing)
        } description: {
            Text(emptyDescription)
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyTitle: String {
        searchText.isEmpty ? "No Listings" : "No Results"
    }

    private var emptyDescription: String {
        searchText.isEmpty
            ? "Listings will appear here"
            : "No listings match \"\(searchText)\""
    }
}

// MARK: - Listing Detail Placeholder

/// Temporary placeholder view for listing details
/// Will be replaced with full ListingDetailView in Phase 4
private struct ListingDetailPlaceholder: View {
    let listing: Listing
    let owner: User?

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: DS.Icons.Entity.listingFill)
                .font(.system(size: 64))
                .foregroundColor(DS.Colors.accent)

            Text(listing.address)
                .font(DS.Typography.title)
                .multilineTextAlignment(.center)

            if !listing.city.isEmpty {
                Text("\(listing.city), \(listing.province) \(listing.postalCode)")
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.Text.secondary)
            }

            if let owner = owner {
                HStack {
                    Image(systemName: DS.Icons.Entity.user)
                    Text(owner.name)
                }
                .font(DS.Typography.bodySecondary)
                .foregroundColor(DS.Colors.Text.secondary)
            }

            Divider()
                .padding(.vertical, DS.Spacing.md)

            HStack(spacing: DS.Spacing.xl) {
                VStack {
                    Text("\(listing.tasks.count)")
                        .font(DS.Typography.title)
                    Text("Tasks")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.Text.secondary)
                }

                VStack {
                    Text("\(listing.activities.count)")
                        .font(DS.Typography.title)
                    Text("Activities")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.Text.secondary)
                }
            }

            Spacer()

            Text("Full detail view coming in Phase 4")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.Text.tertiary)
        }
        .padding(DS.Spacing.lg)
        .navigationTitle("Listing")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview("Listing List View") {
    ListingListView()
        .modelContainer(for: [Listing.self, User.self], inMemory: true)
        .environmentObject(SyncManager.shared)
}
