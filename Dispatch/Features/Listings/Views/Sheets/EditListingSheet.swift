//
//  EditListingSheet.swift
//  Dispatch
//
//  Sheet for editing an existing Listing
//

import SwiftData
import SwiftUI

/// Jobs-Standard sheet for editing an existing Listing.
/// Mirrors AddListingSheet form sections with pre-populated values.
struct EditListingSheet: View {

  // MARK: Lifecycle

  init(listing: Listing) {
    self.listing = listing
    _address = State(initialValue: listing.address)
    _city = State(initialValue: listing.city)
    _province = State(initialValue: listing.province)
    _postalCode = State(initialValue: listing.postalCode)
    _country = State(initialValue: listing.country)
    _price = State(initialValue: listing.price)
    _mlsNumber = State(initialValue: listing.mlsNumber ?? "")
    _selectedTypeId = State(initialValue: listing.typeDefinitionId)
    _selectedOwnerId = State(initialValue: listing.ownedBy)
    _dueDate = State(initialValue: listing.dueDate ?? Date())
    _hasDueDate = State(initialValue: listing.dueDate != nil)
  }

  // MARK: Internal

  let listing: Listing

  var body: some View {
    NavigationStack {
      StandardScreen(
        title: "Edit Listing",
        layout: .column,
        scroll: .disabled
      ) {
        Form {
          addressSection
          locationSection
          detailsSection
          typeSection
          ownerSection
          dueDateSection
        }
        .formStyle(.grouped)
      } toolbarContent: {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { save() }
            .disabled(!canSave)
        }
      }
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var syncManager: SyncManager

  @Query(filter: #Predicate<ListingTypeDefinition> { !$0.isArchived }, sort: \ListingTypeDefinition.position)
  private var listingTypes: [ListingTypeDefinition]

  @Query(sort: \User.name)
  private var allUsers: [User]

  @State private var address: String
  @State private var city: String
  @State private var province: String
  @State private var postalCode: String
  @State private var country: String
  @State private var price: Decimal?
  @State private var mlsNumber: String
  @State private var selectedTypeId: UUID?
  @State private var selectedOwnerId: UUID?
  @State private var dueDate: Date
  @State private var hasDueDate: Bool

  /// Realtors only (filtered client-side due to SwiftData predicate limitations with enums)
  private var realtors: [User] {
    allUsers.filter { $0.userType == .realtor }
  }

  private var trimmedAddress: String {
    address.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var canSave: Bool {
    !trimmedAddress.isEmpty
      && selectedTypeId != nil
      && selectedOwnerId != nil
  }

  private var addressSection: some View {
    Section {
      TextField("Property address", text: $address)
    } header: {
      Text("Address")
    } footer: {
      if trimmedAddress.isEmpty {
        Text("Required")
          .foregroundColor(DS.Colors.destructive)
      }
    }
  }

  private var locationSection: some View {
    Section("Location") {
      TextField("City", text: $city)
      TextField("Province", text: $province)
      TextField("Postal Code", text: $postalCode)
      TextField("Country", text: $country)
    }
  }

  private var detailsSection: some View {
    Section("Details") {
      TextField("Price", value: $price, format: .currency(code: "CAD"))
      #if os(iOS)
        .keyboardType(.decimalPad)
      #endif
      TextField("MLS Number", text: $mlsNumber)
    }
  }

  private var typeSection: some View {
    Section("Type") {
      Picker("Listing Type", selection: $selectedTypeId) {
        ForEach(listingTypes) { type in
          Text(type.name).tag(type.id as UUID?)
        }
      }
      .pickerStyle(.menu)
    }
  }

  private var ownerSection: some View {
    Section("Owner") {
      if realtors.isEmpty {
        Text("No realtors available")
          .foregroundStyle(DS.Colors.Text.secondary)
      } else if realtors.count == 1, selectedOwnerId == realtors.first?.id {
        // Single realtor, auto-selected - show as read-only
        HStack {
          Text("Realtor")
          Spacer()
          Text(realtors.first?.name ?? "")
            .foregroundStyle(DS.Colors.Text.secondary)
        }
      } else {
        Picker("Realtor", selection: $selectedOwnerId) {
          Text("Select Realtor").tag(nil as UUID?)
          ForEach(realtors) { realtor in
            Text(realtor.name).tag(realtor.id as UUID?)
          }
        }
        .pickerStyle(.menu)
      }
    }
  }

  private var dueDateSection: some View {
    Section("Due Date") {
      Toggle("Set Due Date", isOn: $hasDueDate)
      if hasDueDate {
        DatePicker(
          "Due Date",
          selection: $dueDate,
          displayedComponents: [.date]
        )
      }
    }
  }

  private func save() {
    guard
      let typeId = selectedTypeId,
      let ownerId = selectedOwnerId,
      let selectedType = listingTypes.first(where: { $0.id == typeId })
    else { return }

    // Update listing properties
    listing.address = trimmedAddress
    listing.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
    listing.province = province.trimmingCharacters(in: .whitespacesAndNewlines)
    listing.postalCode = postalCode.trimmingCharacters(in: .whitespacesAndNewlines)
    listing.country = country.trimmingCharacters(in: .whitespacesAndNewlines)
    listing.price = price
    listing.mlsNumber = mlsNumber.isEmpty ? nil : mlsNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    listing.ownedBy = ownerId
    listing.typeDefinitionId = typeId
    listing.typeDefinition = selectedType
    listing.listingType = mapToLegacyEnum(selectedType)
    listing.dueDate = hasDueDate ? dueDate : nil

    // Mark dirty to trigger sync
    listing.markPending()

    // Trigger immediate sync attempt (offline first)
    syncManager.requestSync()

    dismiss()
  }

  /// Maps dynamic ListingTypeDefinition to legacy ListingType enum by name.
  private func mapToLegacyEnum(_ type: ListingTypeDefinition) -> ListingType {
    switch type.name.lowercased() {
    case "sale": .sale
    case "lease": .lease
    case "pre-listing": .preListing
    case "rental": .rental
    default: .other
    }
  }
}

// MARK: - Preview

#Preview("Edit Listing Sheet") {
  let listing = Listing(
    address: "123 Main St",
    city: "Toronto",
    province: "ON",
    postalCode: "M5V 2T6",
    ownedBy: UUID()
  )
  return EditListingSheet(listing: listing)
    .environmentObject(SyncManager.preview)
}
