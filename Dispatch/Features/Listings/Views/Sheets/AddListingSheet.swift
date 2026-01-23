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
/// - Platform-adaptive layout (Form on iOS, VStack on macOS)
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
  @State private var realDirt = ""
  @State private var initialNote = ""
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

  // MARK: - Content Views

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
    FormSheetContainer {
      addressSection
      locationSection
      typeSection
      ownerSection
      realDirtSection
      notesSection
    }
  }

  // MARK: - Form Sections

  private var addressSection: some View {
    FormSheetTextRow(
      "Address",
      placeholder: "Property address",
      text: $address,
      isRequired: true,
      errorMessage: "Required"
    )
  }

  private var locationSection: some View {
    FormSheetSection("Location") {
      FormSheetRow("City") {
        TextField("City", text: $city)
      }
      FormSheetRow("Province") {
        TextField("Province", text: $province)
      }
    }
  }

  private var typeSection: some View {
    FormSheetSection("Type") {
      FormSheetPickerRow("Listing Type", selection: $selectedTypeId) {
        ForEach(listingTypes) { type in
          Text(type.name).tag(type.id as UUID?)
        }
      }
    }
  }

  @ViewBuilder
  private var ownerSection: some View {
    FormSheetSection("Owner") {
      if realtors.isEmpty {
        noRealtorsView
      } else if realtors.count == 1, selectedOwnerId == realtors.first?.id {
        singleRealtorView
      } else {
        realtorPickerView
      }
    }
  }

  private var noRealtorsView: some View {
    Text("No realtors available")
      .foregroundStyle(DS.Colors.Text.secondary)
  }

  private var singleRealtorView: some View {
    HStack {
      Text("Realtor")
      Spacer()
      Text(realtors.first?.name ?? "")
        .foregroundStyle(DS.Colors.Text.secondary)
    }
    .frame(minHeight: DS.Spacing.minTouchTarget)
  }

  private var realtorPickerView: some View {
    FormSheetPickerRow("Realtor", selection: $selectedOwnerId) {
      Text("Select Realtor").tag(nil as UUID?)
      ForEach(realtors) { realtor in
        Text(realtor.name).tag(realtor.id as UUID?)
      }
    }
  }

  private var realDirtSection: some View {
    FormSheetSection("Real Dirt") {
      FormSheetTextRow(
        "Details",
        placeholder: "Insider info, history, quirks...",
        text: $realDirt,
        axis: .vertical,
        lineLimit: 1 ... 5
      )
    }
  }

  private var notesSection: some View {
    FormSheetSection("Notes") {
      FormSheetTextRow(
        "Note",
        placeholder: "Initial note...",
        text: $initialNote,
        axis: .vertical,
        lineLimit: 1 ... 5
      )
    }
  }

  // MARK: - Actions

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

    // Set realDirt if provided
    let trimmedRealDirt = realDirt.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedRealDirt.isEmpty {
      listing.realDirt = trimmedRealDirt
    }

    modelContext.insert(listing)
    listing.markPending()

    // Create initial note if provided
    let trimmedNote = initialNote.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedNote.isEmpty {
      let note = Note(
        content: trimmedNote,
        createdBy: currentUserId,
        parentType: .listing,
        parentId: listing.id
      )
      modelContext.insert(note)
      listing.notes.append(note)
    }

    onSave()
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

#Preview("Add Listing Sheet") {
  AddListingSheet(
    currentUserId: UUID(),
    onSave: { }
  )
  .environmentObject(SyncManager.preview)
}
