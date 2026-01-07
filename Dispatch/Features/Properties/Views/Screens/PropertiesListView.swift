//
//  PropertiesListView.swift
//  Dispatch
//
//  Main screen for displaying and managing properties
//

import SwiftUI
import SwiftData

/// A group of properties belonging to a single owner
private struct PropertyGroup: Identifiable {
    var id: String { owner?.id.uuidString ?? "unknown" }
    let owner: User?
    let properties: [Property]
}

struct PropertiesListView: View {

    @Query(sort: \Property.address)
    private var allPropertiesRaw: [Property]

    /// Filter out deleted properties
    private var allProperties: [Property] {
        allPropertiesRaw.filter { $0.deletedAt == nil }
    }

    @Query private var users: [User]

    @EnvironmentObject private var syncManager: SyncManager
    @Environment(\.modelContext) private var modelContext

    // MARK: - Computed Properties

    /// Pre-computed user lookup dictionary for O(1) access
    private var userCache: [UUID: User] {
        Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
    }

    /// Properties grouped by owner, sorted by owner name
    private var groupedByOwner: [PropertyGroup] {
        let properties: [Property] = allProperties
        let grouped: [UUID: [Property]] = Dictionary(grouping: properties) { $0.ownedBy }

        let groups: [PropertyGroup] = grouped.map { (key: UUID, value: [Property]) -> PropertyGroup in
            return PropertyGroup(owner: userCache[key], properties: value)
        }

        return groups.sorted { (a: PropertyGroup, b: PropertyGroup) -> Bool in
            let nameA = a.owner?.name ?? "~"
            let nameB = b.owner?.name ?? "~"
            return nameA < nameB
        }
    }

    // MARK: - Body

    var body: some View {
        StandardScreen(title: "Properties", layout: .column, scroll: .disabled) {
            StandardList(groupedByOwner) { group in
                Section(group.owner?.name ?? "Unknown Owner") {
                    ForEach(group.properties) { property in
                        NavigationLink(value: property) {
                            PropertyRow(property: property, owner: group.owner)
                        }
                    }
                }
            } emptyContent: {
                ContentUnavailableView {
                    Label("No Properties", systemImage: DS.Icons.Entity.property)
                } description: {
                    Text("Properties will appear here")
                }
            }
            .pullToSearch()

        } toolbarContent: {
            ToolbarItem(placement: .automatic) {
                EmptyView()
            }
        }
    }
}

// MARK: - Preview
#Preview("Properties List View") {
    PropertiesListView()
        .modelContainer(for: [Property.self, User.self], inMemory: true)
        .environmentObject(SyncManager(mode: .preview))
}
