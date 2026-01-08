//
//  ListingTypeListView.swift
//  Dispatch
//
//  Lists all ListingTypeDefinitions for admin management.
//  Part of Listing Types & Activity Templates feature.
//

import SwiftData
import SwiftUI

// MARK: - ListingTypeListView

/// Displays all ListingTypeDefinitions, allowing admins to add/edit types.
struct ListingTypeListView: View {

  // MARK: Internal

  var body: some View {
    StandardScreen(title: "Listing Types", layout: .column, scroll: .disabled) {
      StandardList(visibleTypes) { listingType in
        ListRowLink(value: AppRoute.listingType(listingType.id)) {
          ListingTypeRow(listingType: listingType)
        }
      } emptyContent: {
        ContentUnavailableView {
          Label("No Listing Types", systemImage: DS.Icons.Entity.listing)
        } description: {
          Text("Create listing types to enable auto-generated activities.")
        }
      }
    } toolbarContent: {
      ToolbarItem(placement: .primaryAction) {
        Button {
          showAddSheet = true
        } label: {
          Image(systemName: "plus")
        }
      }

      #if os(macOS)
      ToolbarItem(placement: .automatic) {
        Toggle("Show Archived", isOn: $showArchivedTypes)
          .toggleStyle(.checkbox)
      }
      #else
      ToolbarItem(placement: .topBarLeading) {
        Menu {
          Toggle("Show Archived", isOn: $showArchivedTypes)
        } label: {
          Image(systemName: "line.3.horizontal.decrease.circle")
        }
      }
      #endif
    }
    .sheet(isPresented: $showAddSheet) {
      ListingTypeEditorSheet()
    }
  }

  // MARK: Private

  @Query(sort: \ListingTypeDefinition.position)
  private var listingTypes: [ListingTypeDefinition]

  @EnvironmentObject private var syncManager: SyncManager
  @Environment(\.modelContext) private var modelContext

  @State private var showAddSheet = false
  @State private var showArchivedTypes = false

  /// Filtered list based on archive toggle
  private var visibleTypes: [ListingTypeDefinition] {
    showArchivedTypes ? listingTypes : listingTypes.filter { !$0.isArchived }
  }

}

// MARK: - ListingTypeRow

private struct ListingTypeRow: View {
  let listingType: ListingTypeDefinition

  var body: some View {
    HStack(spacing: DS.Spacing.md) {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: DS.Spacing.xs) {
          Text(listingType.name)
            .font(DS.Typography.body)
            .foregroundStyle(DS.Colors.Text.primary)

          if listingType.isSystem {
            Text("System")
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Colors.Text.tertiary)
              .padding(.horizontal, DS.Spacing.xs)
              .padding(.vertical, 2)
              .background(DS.Colors.Background.secondary)
              .cornerRadius(DS.Spacing.radiusSmall)
          }

          if listingType.isArchived {
            Text("Archived")
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Colors.Text.disabled)
              .padding(.horizontal, DS.Spacing.xs)
              .padding(.vertical, 2)
              .background(DS.Colors.Background.tertiary)
              .cornerRadius(DS.Spacing.radiusSmall)
          }
        }

        Text("\(listingType.templates.count) templates")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.secondary)
      }

      Spacer()
    }
    .padding(.vertical, DS.Spacing.md)
    .contentShape(Rectangle())
  }
}

// MARK: - ListingTypeEditorSheet

private struct ListingTypeEditorSheet: View {

  // MARK: Internal

  var body: some View {
    NavigationStack {
      Form {
        Section("Details") {
          TextField("Name", text: $name)
        }
      }
      .navigationTitle("New Listing Type")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") { save() }
              .disabled(!isValid)
          }
        }
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject private var syncManager: SyncManager

  @State private var name = ""

  private var isValid: Bool {
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func save() {
    guard let currentUserId = syncManager.currentUserID else { return }

    let listingType = ListingTypeDefinition(
      name: name.trimmingCharacters(in: .whitespacesAndNewlines),
      isSystem: false,
      ownedBy: currentUserId,
    )
    modelContext.insert(listingType)
    listingType.markPending()
    syncManager.requestSync()
    dismiss()
  }
}

// MARK: - Preview

#Preview {
  PreviewShell { context in
    // Seed sample listing types
    let saleType = ListingTypeDefinition(
      id: UUID(),
      name: "Sale",
      isSystem: true,
      position: 0,
    )
    context.insert(saleType)

    let leaseType = ListingTypeDefinition(
      id: UUID(),
      name: "Lease",
      isSystem: true,
      position: 1,
    )
    context.insert(leaseType)
  } content: { _ in
    ListingTypeListView()
  }
}
