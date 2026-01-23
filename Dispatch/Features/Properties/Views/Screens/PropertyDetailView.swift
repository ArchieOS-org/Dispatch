//
//  PropertyDetailView.swift
//  Dispatch
//
//  Full detail view for a Property
//

import Supabase
import SwiftData
import SwiftUI

// MARK: - PropertyDetailView

struct PropertyDetailView: View {

  // MARK: Internal

  let property: Property
  let userLookup: (UUID) -> User?

  var body: some View {
    StandardScreen(title: property.displayAddress.titleCased(), layout: .column, scroll: .automatic) {
      content
    } toolbarContent: {
      // On iPhone (compact size class), show menu in toolbar
      // On macOS and iPad, menu appears beside title via titleMenu instead
      ToolbarItem(placement: .primaryAction) {
        #if os(iOS)
        if horizontalSizeClass == .compact {
          OverflowMenu(actions: propertyActions)
        }
        #endif
      }
    } titleMenu: {
      // On macOS and iPad, menu appears beside title via titleMenu
      OverflowMenu(actions: propertyActions)
    }
    .alert("Delete Property?", isPresented: $showDeleteAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Delete", role: .destructive) {
        deleteProperty()
      }
    } message: {
      Text("This property will be marked as deleted. Associated listings will be unlinked.")
    }
  }

  // MARK: Private

  /// Scaled empty state icon size for Dynamic Type support (base: 32pt)
  @ScaledMetric(relativeTo: .title)
  private var emptyStateIconSize: CGFloat = 32

  #if os(iOS)
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  #endif

  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var syncManager: SyncManager
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  @State private var showDeleteAlert = false

  private var owner: User? {
    userLookup(property.ownedBy)
  }

  /// Listings sorted by creation date (newest first)
  private var sortedListings: [Listing] {
    property.activeListings.sorted { $0.createdAt > $1.createdAt }
  }

  private var propertyActions: [OverflowMenu.Action] {
    [
      OverflowMenu.Action(id: "edit", title: "Edit Property", icon: DS.Icons.Action.edit) {
        // Edit placeholder
      },
      OverflowMenu.Action(id: "delete", title: "Delete Property", icon: DS.Icons.Action.delete, role: .destructive) {
        showDeleteAlert = true
      }
    ]
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
      metadataSection

      listingsSection

      // History Section
      HistorySection(
        entityType: .property,
        entityId: property.id,
        currentUserId: syncManager.currentUserID ?? UUID(),
        userLookup: userLookup,
        supabase: supabase,
        onRestore: nil
      )
    }
    .padding(.bottom, DS.Spacing.md)
  }

  private var metadataSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      // Location
      if !property.city.isEmpty {
        Text("\(property.city.titleCased()), \(property.province.titleCased()) \(property.postalCode)")
          .font(DS.Typography.body)
          .foregroundColor(DS.Colors.Text.secondary)
      }

      Divider().padding(.top, DS.Spacing.sm)

      // Owner and property type
      HStack {
        if let owner {
          RealtorPill(realtorID: owner.id, realtorName: owner.name)
        }

        Spacer()

        // Property type badge
        HStack(spacing: DS.Spacing.xs) {
          Image(systemName: property.propertyType.icon)
          Text(property.propertyType.displayName)
        }
        .font(DS.Typography.caption)
        .foregroundColor(DS.Colors.Section.properties)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(DS.Colors.Section.properties.opacity(0.15))
        .clipShape(Capsule())
      }
      .padding(.top, DS.Spacing.xs)

      Divider().padding(.top, DS.Spacing.sm)
    }
  }

  private var listingsSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      listingsHeader
      Divider().padding(.vertical, DS.Spacing.sm)
      listingsContent
    }
  }

  private var listingsHeader: some View {
    HStack {
      Text("Listing History")
        .font(DS.Typography.headline)
        .foregroundColor(DS.Colors.Text.primary)
      Text("(\(sortedListings.count))")
        .font(DS.Typography.bodySecondary)
        .foregroundColor(DS.Colors.Text.secondary)
      Spacer()
    }
  }

  private var listingsContent: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      if sortedListings.isEmpty {
        emptyStateView(
          icon: DS.Icons.Entity.listing,
          title: "No Listings",
          message: "Listings for this property will appear here"
        )
      } else {
        VStack(spacing: 0) {
          ForEach(sortedListings) { listing in
            NavigationLink(value: AppRoute.listing(listing.id)) {
              PropertyListingRow(listing: listing)
                .padding(.vertical, DS.Spacing.xs)
            }
            .buttonStyle(.plain)

            if listing.id != sortedListings.last?.id {
              Divider()
            }
          }
        }
      }
    }
  }

  private func emptyStateView(icon: String, title: String, message: String) -> some View {
    VStack(spacing: DS.Spacing.sm) {
      Image(systemName: icon)
        .font(.system(size: emptyStateIconSize))
        .foregroundColor(DS.Colors.Text.tertiary)
      Text(title)
        .font(DS.Typography.headline)
        .foregroundColor(DS.Colors.Text.secondary)
      Text(message)
        .font(DS.Typography.caption)
        .foregroundColor(DS.Colors.Text.tertiary)
    }
    .padding(.vertical, DS.Spacing.xl)
  }

  private func deleteProperty() {
    property.deletedAt = Date()
    property.markPending()
    syncManager.requestSync()
    dismiss()
    // Clean up navigation path to prevent navigating back to deleted property
    appState.dispatch(.removeRoute(.property(property.id)))
  }

}

// MARK: - PropertyListingRow

private struct PropertyListingRow: View {

  // MARK: Internal

  let listing: Listing

  var body: some View {
    HStack(spacing: DS.Spacing.md) {
      // Stage indicator (decorative - stage name shown in pill)
      Circle()
        .fill(listing.stage.color)
        .frame(width: 10, height: 10)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text(listing.listingType.rawValue.capitalized)
          .font(DS.Typography.body)
          .foregroundColor(DS.Colors.Text.primary)

        Text(formatDate(listing.createdAt))
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.secondary)
      }

      Spacer()

      // Stage pill
      Text(listing.stage.displayName)
        .font(DS.Typography.caption)
        .foregroundColor(listing.stage.color)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(listing.stage.color.opacity(0.15))
        .clipShape(Capsule())
    }
    .contentShape(Rectangle())
  }

  // MARK: Private

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy"
    return formatter.string(from: date)
  }
}

// MARK: - Previews

#Preview("Property Detail View") {
  PreviewShell(
    setup: { context in
      PreviewDataFactory.seed(context)

      // Add a property for preview
      let property = Property(
        address: "123 Main Street",
        unit: "4B",
        city: "Toronto",
        province: "ON",
        postalCode: "M5V 1A1",
        ownedBy: PreviewDataFactory.aliceID
      )
      property.syncState = .synced
      context.insert(property)
    }
  ) { context in
    let users = (try? context.fetch(FetchDescriptor<User>())) ?? []
    let usersById = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })

    let propertyDescriptor = FetchDescriptor<Property>(predicate: #Predicate { $0.address == "123 Main Street" })
    if let property = try? context.fetch(propertyDescriptor).first {
      PropertyDetailView(
        property: property,
        userLookup: { id in usersById[id] }
      )
    } else {
      Text("Missing preview data")
    }
  }
}

#Preview("Property with Listings") {
  PreviewShell(
    setup: { context in
      PreviewDataFactory.seed(context)

      // Add a property with listings
      let property = Property(
        address: "456 Oak Avenue",
        city: "Vancouver",
        province: "BC",
        postalCode: "V6B 1A1",
        ownedBy: PreviewDataFactory.bobID
      )
      property.syncState = .synced
      context.insert(property)

      // Add a listing linked to this property
      let listing = Listing(
        address: "456 Oak Avenue",
        status: .active,
        ownedBy: PreviewDataFactory.bobID
      )
      listing.city = "Vancouver"
      listing.province = "BC"
      listing.syncState = .synced
      listing.property = property
      context.insert(listing)
    }
  ) { context in
    let users = (try? context.fetch(FetchDescriptor<User>())) ?? []
    let usersById = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })

    let propertyDescriptor = FetchDescriptor<Property>(predicate: #Predicate { $0.address == "456 Oak Avenue" })
    if let property = try? context.fetch(propertyDescriptor).first {
      PropertyDetailView(
        property: property,
        userLookup: { id in usersById[id] }
      )
    } else {
      Text("Missing preview data")
    }
  }
}
