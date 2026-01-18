//
//  PropertiesListView.swift
//  Dispatch
//
//  Main screen for displaying and managing properties
//

import SwiftData
import SwiftUI

// MARK: - PropertyGroup

/// A group of properties belonging to a single owner
private struct PropertyGroup: Identifiable {
  let owner: User?
  let properties: [Property]

  var id: String {
    owner?.id.uuidString ?? "unknown"
  }
}

// MARK: - PropertiesListView

struct PropertiesListView: View {

  // MARK: Internal

  var body: some View {
    StandardScreen(title: "Properties", layout: .column, scroll: .automatic) {
      if groupedByOwner.isEmpty {
        // Caller handles empty state
        ContentUnavailableView {
          Label("No Properties", systemImage: DS.Icons.Entity.property)
        } description: {
          Text("Properties will appear here")
        }
      } else {
        StandardGroupedList(
          groupedByOwner,
          items: { $0.properties },
          header: { group in
            SectionHeader(group.owner?.name ?? "Unknown Owner")
          },
          row: { group, property in
            ListRowLink(value: AppRoute.property(property.id)) {
              PropertyRow(property: property, owner: group.owner)
            }
          }
        )
      }
    } toolbarContent: {
      ToolbarItem(placement: .automatic) {
        EmptyView()
      }
    }
    #if os(macOS)
    .onMoveCommand { direction in
      handleMoveCommand(direction)
    }
    .onDeleteCommand {
      handleDeleteCommand()
    }
    .alert("Delete Property?", isPresented: $showDeletePropertyAlert) {
      Button("Cancel", role: .cancel) {
        propertyToDelete = nil
      }
      Button("Delete", role: .destructive) {
        confirmDeleteFocusedProperty()
      }
    } message: {
      Text("This property will be marked as deleted.")
    }
    #endif
  }

  // MARK: Private

  @Query(sort: \Property.address)
  private var allPropertiesRaw: [Property]

  @Query private var users: [User]

  @EnvironmentObject private var syncManager: SyncManager
  @Environment(\.modelContext) private var modelContext

  #if os(macOS)
  /// Tracks the currently focused property ID for keyboard navigation
  @FocusState private var focusedPropertyID: UUID?

  /// State for keyboard-triggered property deletion
  @State private var showDeletePropertyAlert = false
  @State private var propertyToDelete: Property?
  #endif

  /// Filter out deleted properties
  private var allProperties: [Property] {
    allPropertiesRaw.filter { $0.deletedAt == nil }
  }

  /// Pre-computed user lookup dictionary for O(1) access
  private var userCache: [UUID: User] {
    Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
  }

  /// Properties grouped by owner, sorted by owner name
  private var groupedByOwner: [PropertyGroup] {
    let properties: [Property] = allProperties
    let grouped: [UUID: [Property]] = Dictionary(grouping: properties) { $0.ownedBy }

    let groups: [PropertyGroup] = grouped.map { (key: UUID, value: [Property]) -> PropertyGroup in
      PropertyGroup(owner: userCache[key], properties: value)
    }

    return groups.sorted { (a: PropertyGroup, b: PropertyGroup) -> Bool in
      let nameA = a.owner?.name ?? "~"
      let nameB = b.owner?.name ?? "~"
      return nameA < nameB
    }
  }

  /// Flat list of all property IDs for keyboard navigation
  private var allPropertyIDs: [UUID] {
    groupedByOwner.flatMap { $0.properties.map(\.id) }
  }

  #if os(macOS)
  /// Handles arrow key navigation in the properties list
  private func handleMoveCommand(_ direction: MoveCommandDirection) {
    let ids = allPropertyIDs
    guard !ids.isEmpty else { return }

    switch direction {
    case .up:
      if
        let currentID = focusedPropertyID,
        let currentIndex = ids.firstIndex(of: currentID),
        currentIndex > 0
      {
        focusedPropertyID = ids[currentIndex - 1]
      } else {
        // No selection or at top - select first item
        focusedPropertyID = ids.first
      }

    case .down:
      if
        let currentID = focusedPropertyID,
        let currentIndex = ids.firstIndex(of: currentID),
        currentIndex < ids.count - 1
      {
        focusedPropertyID = ids[currentIndex + 1]
      } else if focusedPropertyID == nil {
        // No selection - select first item
        focusedPropertyID = ids.first
      }

    case .left, .right:
      // Left/right not used for vertical lists
      break

    @unknown default:
      break
    }
  }

  /// Handles Delete key press - shows confirmation alert for focused property
  private func handleDeleteCommand() {
    guard
      let focusedID = focusedPropertyID,
      let property = allProperties.first(where: { $0.id == focusedID })
    else { return }

    propertyToDelete = property
    showDeletePropertyAlert = true
  }

  /// Confirms deletion of the focused property
  private func confirmDeleteFocusedProperty() {
    guard let property = propertyToDelete else { return }
    property.deletedAt = Date()
    // Note: Property doesn't have markPending in the model, so we just update
    syncManager.requestSync()
    propertyToDelete = nil
    focusedPropertyID = nil
  }
  #endif

}

// MARK: - Preview
#Preview("Properties List View") {
  PropertiesListView()
    .modelContainer(for: [Property.self, User.self], inMemory: true)
    .environmentObject(SyncManager(mode: .preview))
}
