//
//  AddPropertySheet.swift
//  Dispatch
//
//  Sheet for creating a new Property (Jobs-Standard)
//

import SwiftData
import SwiftUI

/// Jobs-Standard sheet for creating a new Property.
/// Features:
/// - Optional realtor pre-selection via forRealtorId
/// - Address and location fields
/// - Owner (realtor) selection
struct AddPropertySheet: View {

  // MARK: Lifecycle

  init(
    currentUserId: UUID,
    forRealtorId: UUID? = nil,
    onSave: @escaping () -> Void
  ) {
    self.currentUserId = currentUserId
    self.forRealtorId = forRealtorId
    self.onSave = onSave
  }

  // MARK: Internal

  /// Current user ID for smart defaults
  let currentUserId: UUID

  /// Optional pre-selected realtor (from FAB context)
  let forRealtorId: UUID?

  /// Callback when save completes (for triggering sync)
  let onSave: () -> Void

  var body: some View {
    NavigationStack {
      formContent
        .navigationTitle("New Property")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Add") { saveAndDismiss() }
              .disabled(!canSave)
          }
        }
        .onAppear { setSmartDefaults() }
        .task(id: allUsers.count) {
          setSmartDefaults()
        }
    }
    #if os(iOS)
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    #endif
  }

  // MARK: Private

  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  @Query(sort: \User.name)
  private var allUsers: [User]

  @State private var address = ""
  @State private var city = ""
  @State private var province = ""
  @State private var postalCode = ""
  @State private var selectedOwnerId: UUID?

  /// Realtors only (filtered client-side due to SwiftData predicate limitations with enums)
  private var realtors: [User] {
    allUsers.filter { $0.userType == .realtor }
  }

  private var trimmedAddress: String {
    address.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var canSave: Bool {
    !trimmedAddress.isEmpty && selectedOwnerId != nil
  }

  private var formContent: some View {
    Form {
      addressSection
      locationSection
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
          .foregroundStyle(DS.Colors.destructive)
      }
    }
  }

  private var locationSection: some View {
    Section("Location") {
      TextField("City", text: $city)
      TextField("Province", text: $province)
      TextField("Postal Code", text: $postalCode)
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
    // If realtor pre-selected via FAB context, use that
    if let realtorId = forRealtorId, realtors.contains(where: { $0.id == realtorId }) {
      selectedOwnerId = realtorId
      return
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
    guard let ownerId = selectedOwnerId else { return }

    let property = Property(
      address: trimmedAddress,
      city: city.trimmingCharacters(in: .whitespacesAndNewlines),
      province: province.trimmingCharacters(in: .whitespacesAndNewlines),
      postalCode: postalCode.trimmingCharacters(in: .whitespacesAndNewlines),
      ownedBy: ownerId
    )

    modelContext.insert(property)
    onSave()
    dismiss()
  }
}

// MARK: - Preview

#Preview("Add Property Sheet") {
  PreviewShell { _ in
    AddPropertySheet(
      currentUserId: PreviewDataFactory.aliceID,
      onSave: { }
    )
  }
}

#Preview("Add Property Sheet - Pre-selected Realtor") {
  PreviewShell { _ in
    AddPropertySheet(
      currentUserId: PreviewDataFactory.aliceID,
      forRealtorId: PreviewDataFactory.bobID,
      onSave: { }
    )
  }
}
