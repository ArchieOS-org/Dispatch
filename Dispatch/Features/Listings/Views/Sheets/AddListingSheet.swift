//
//  AddListingSheet.swift
//  Dispatch
//
//  Sheet for creating a new Listing (Jobs-Standard)
//

import SwiftData
import SwiftUI

/// Jobs-Standard sheet for creating a new Listing.
/// Features:
/// - ID-based picker state (stable selection)
/// - Scoped queries (non-archived types, realtors only)
/// - Smart defaults (system "Sale", current user if Realtor)
/// - Single source of truth (ownedBy is authoritative)
/// - Legacy enum derived, not hardcoded
struct AddListingSheet: View {

  // MARK: Internal

  /// Current user ID for smart defaults
  let currentUserId: UUID

  /// Callback when save completes (for triggering sync)
  var onSave: () -> Void

  var body: some View {
    NavigationStack {
      Group {
        if syncManager.isListingConfigReady {
          formContent
        } else {
          loadingContent
        }
      }
      .navigationTitle("New Listing")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Add") { saveAndDismiss() }
              .disabled(!canSave || !syncManager.isListingConfigReady)
          }
        }
        .onAppear { setSmartDefaults() }
    }
    #if os(iOS)
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    #endif
  }

  // MARK: Private

  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var syncManager: SyncManager

  @Query(filter: #Predicate<ListingTypeDefinition> { !$0.isArchived }, sort: \ListingTypeDefinition.position)
  private var listingTypes: [ListingTypeDefinition]

  @Query(sort: \User.name)
  private var allUsers: [User]

  @State private var address = ""
  @State private var city = ""
  @State private var province = ""
  @State private var selectedTypeId: UUID?
  @State private var selectedOwnerId: UUID?

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

  private var selectedType: ListingTypeDefinition? {
    listingTypes.first { $0.id == selectedTypeId }
  }

  private var loadingContent: some View {
    VStack(spacing: DS.Spacing.md) {
      ProgressView()
      Text("Loading configuration...")
        .font(DS.Typography.body)
        .foregroundStyle(DS.Colors.Text.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var formContent: some View {
    Form {
      addressSection
      locationSection
      typeSection
      ownerSection
    }
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

  private func setSmartDefaults() {
    // Default type: "Sale" by name, fallback to first type
    if selectedTypeId == nil {
      selectedTypeId = listingTypes.first { $0.name.lowercased() == "sale" }?.id
        ?? listingTypes.first?.id
    }

    // Default owner: current user if Realtor, else single Realtor if only one
    if selectedOwnerId == nil {
      if let me = realtors.first(where: { $0.id == currentUserId }) {
        selectedOwnerId = me.id
      } else if realtors.count == 1 {
        selectedOwnerId = realtors.first?.id
      }
    }
  }

  private func saveAndDismiss() {
    guard
      let typeId = selectedTypeId,
      let ownerId = selectedOwnerId,
      let selectedType = listingTypes.first(where: { $0.id == typeId })
    else { return }

    let listing = Listing(
      address: trimmedAddress,
      city: city.trimmingCharacters(in: .whitespacesAndNewlines),
      province: province.trimmingCharacters(in: .whitespacesAndNewlines),
      listingType: mapToLegacyEnum(selectedType),
      ownedBy: ownerId // Single source of truth
    )
    listing.typeDefinitionId = typeId
    listing.typeDefinition = selectedType

    modelContext.insert(listing)
    listing.markPending()
    onSave()
    dismiss()
  }

  /// Maps dynamic ListingTypeDefinition to legacy ListingType enum by name.
  private func mapToLegacyEnum(_ type: ListingTypeDefinition) -> ListingType {
    switch type.name.lowercased() {
    case "sale": return .sale
    case "lease": return .lease
    case "pre-listing": return .preListing
    case "rental": return .rental
    default: return .other
    }
  }
}

// MARK: - Preview

#Preview("Add Listing Sheet") {
  AddListingSheet(
    currentUserId: UUID(),
    onSave: { }
  )
}
