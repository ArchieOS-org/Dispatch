//
//  AddListingSheet.swift
//  Dispatch
//
//  Sheet for creating a new Listing
//

import SwiftUI
import SwiftData

/// Simple sheet for creating a new Listing.
/// Listings have different fields than Tasks/Activities (address-based instead of title-based).
///
/// Usage:
/// ```swift
/// .sheet(isPresented: $showAddListing) {
///     AddListingSheet(
///         currentUserId: currentUserId,
///         onSave: { syncManager.requestSync() }
///     )
/// }
/// ```
struct AddListingSheet: View {
    /// Current user ID for ownedBy field
    let currentUserId: UUID

    /// Callback when save completes (for triggering sync)
    var onSave: () -> Void

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Form State

    @State private var address: String = ""
    @State private var city: String = ""
    @State private var province: String = ""
    @State private var listingType: ListingType = .sale

    // MARK: - Computed Properties

    private var canSave: Bool {
        !address.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Property address", text: $address)
                } header: {
                    Text("Address")
                } footer: {
                    if address.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("Required")
                            .foregroundColor(DS.Colors.destructive)
                    }
                }

                Section("Location") {
                    TextField("City", text: $city)
                    TextField("Province", text: $province)
                }

                Section("Type") {
                    Picker("Listing Type", selection: $listingType) {
                        ForEach(ListingType.allCases, id: \.self) { type in
                            Text(listingTypeLabel(type)).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("New Listing")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveAndDismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        #endif
    }

    // MARK: - Helpers

    private func listingTypeLabel(_ type: ListingType) -> String {
        switch type {
        case .sale: return "Sale"
        case .lease: return "Lease"
        case .preListing: return "Pre-Listing"
        case .rental: return "Rental"
        case .other: return "Other"
        }
    }

    // MARK: - Save Logic

    private func saveAndDismiss() {
        let trimmedAddress = address.trimmingCharacters(in: .whitespaces)
        guard !trimmedAddress.isEmpty else { return }

        let listing = Listing(
            address: trimmedAddress,
            city: city.trimmingCharacters(in: .whitespaces),
            province: province.trimmingCharacters(in: .whitespaces),
            listingType: listingType,
            ownedBy: currentUserId
        )

        modelContext.insert(listing)

        // TODO: Show toast "Listing added"
        onSave()
        dismiss()
    }
}

// MARK: - Preview

#Preview("Add Listing Sheet") {
    AddListingSheet(
        currentUserId: UUID(),
        onSave: { print("Listing saved!") }
    )
}
