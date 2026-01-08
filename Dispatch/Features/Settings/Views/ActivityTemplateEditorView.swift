//
//  ActivityTemplateEditorView.swift
//  Dispatch
//
//  Editor for creating/editing ActivityTemplates with strict audience chips.
//  Part of Listing Types & Activity Templates feature.
//

import SwiftData
import SwiftUI

// MARK: - ActivityTemplateEditorView

/// Editor sheet for ActivityTemplates.
/// Features:
/// - Title (required)
/// - Description (optional)
/// - Audience selection (Chips, NOT free text)
/// - Default Assignee (optional)
struct ActivityTemplateEditorView: View {

  // MARK: Lifecycle

  init(listingType: ListingTypeDefinition, existingTemplate: ActivityTemplate? = nil) {
    self.listingType = listingType
    self.existingTemplate = existingTemplate
  }

  // MARK: Internal

  let listingType: ListingTypeDefinition
  let existingTemplate: ActivityTemplate?

  var body: some View {
    NavigationStack {
      Form {
        // Title Section
        Section("Details") {
          TextField("Title *", text: $title)

          TextField("Description", text: $templateDescription, axis: .vertical)
            .lineLimit(3 ... 6)
        }

        // Audience Section - Chips Only
        Section {
          VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Who should see this activity?")
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Colors.Text.secondary)

            HStack(spacing: DS.Spacing.sm) {
              ForEach(availableAudiences, id: \.self) { audience in
                AudienceToggleChip(
                  audience: audience,
                  isSelected: selectedAudiences.contains(audience),
                ) {
                  toggleAudience(audience)
                }
              }
            }
          }
          .padding(.vertical, DS.Spacing.xs)
        } header: {
          Text("Audience")
        }

        // Default Assignee Section
        Section {
          Picker("Default Assignee", selection: $defaultAssigneeId) {
            Text("None").tag(nil as UUID?)
            ForEach(users) { user in
              Text(user.name).tag(user.id as UUID?)
            }
          }
        } header: {
          Text("Assignment")
        } footer: {
          Text("If set, new activities will be assigned to this user.")
        }
      }
      .navigationTitle(isEditing ? "Edit Template" : "New Template")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button(isEditing ? "Save" : "Add") { save() }
              .disabled(!isValid)
          }
        }
        .onAppear {
          if let template = existingTemplate {
            title = template.title
            templateDescription = template.templateDescription
            selectedAudiences = Set(template.audiencesRaw)
            defaultAssigneeId = template.defaultAssigneeId
          }
        }
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject private var syncManager: SyncManager

  @State private var title = ""
  @State private var templateDescription = ""
  @State private var selectedAudiences = Set<String>()
  @State private var defaultAssigneeId: UUID?

  @Query(sort: \User.name)
  private var users: [User]

  private let availableAudiences = ["admin", "marketing"]

  private var isEditing: Bool {
    existingTemplate != nil
  }

  private var isValid: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func toggleAudience(_ audience: String) {
    if selectedAudiences.contains(audience) {
      selectedAudiences.remove(audience)
    } else {
      selectedAudiences.insert(audience)
    }
  }

  private func save() {
    if let template = existingTemplate {
      // Update existing
      template.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
      template.templateDescription = templateDescription
      template.audiencesRaw = Array(selectedAudiences)
      template.defaultAssigneeId = defaultAssigneeId
      template.markPending()
    } else {
      // Create new
      let nextPosition = listingType.templates.count
      let template = ActivityTemplate(
        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
        templateDescription: templateDescription,
        position: nextPosition,
        audiencesRaw: Array(selectedAudiences),
        listingTypeId: listingType.id,
        defaultAssigneeId: defaultAssigneeId,
      )
      template.listingType = listingType
      modelContext.insert(template)
      template.markPending()
    }

    syncManager.requestSync()
    dismiss()
  }
}

// MARK: - AudienceToggleChip

private struct AudienceToggleChip: View {

  // MARK: Internal

  let audience: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: DS.Spacing.xxs) {
        if isSelected {
          Image(systemName: "checkmark")
            .font(.system(size: 10, weight: .bold))
        }
        Text(audience.capitalized)
          .font(DS.Typography.body)
      }
      .foregroundStyle(isSelected ? .white : color)
      .padding(.horizontal, DS.Spacing.md)
      .padding(.vertical, DS.Spacing.sm)
      .background(isSelected ? color : color.opacity(0.15))
      .cornerRadius(DS.Spacing.radiusCard)
    }
    .buttonStyle(.plain)
  }

  // MARK: Private

  private var color: Color {
    switch audience.lowercased() {
    case "admin": DS.Colors.info
    case "marketing": DS.Colors.warning
    default: DS.Colors.Text.tertiary
    }
  }

}

// MARK: - Preview

#Preview {
  PreviewShell { context in
    let saleType = ListingTypeDefinition(
      id: UUID(),
      name: "Sale",
      isSystem: false,
      position: 0,
      ownedBy: UUID(),
    )
    context.insert(saleType)
  } content: { context in
    if let saleType = try? context.fetch(FetchDescriptor<ListingTypeDefinition>()).first {
      ActivityTemplateEditorView(listingType: saleType)
    } else {
      Text("Missing listing type")
    }
  }
}
