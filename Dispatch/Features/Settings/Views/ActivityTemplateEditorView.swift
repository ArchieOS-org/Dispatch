//
//  ActivityTemplateEditorView.swift
//  Dispatch
//
//  Editor for creating/editing ActivityTemplates with strict audience chips.
//  Part of Listing Types & Activity Templates feature.
//

import SwiftData
import SwiftUI

// MARK: - AudienceSelection

/// Represents the mutually exclusive audience selection.
/// Templates may have no audience set (inherits from context).
private enum AudienceSelection: String, CaseIterable, Identifiable {
  case none = ""
  case admin
  case marketing

  // MARK: Internal

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .none: "None"
    case .admin: "Admin"
    case .marketing: "Marketing"
    }
  }

  var color: Color {
    switch self {
    case .none: DS.Colors.Text.tertiary
    case .admin: DS.Colors.info
    case .marketing: DS.Colors.warning
    }
  }
}

// MARK: - ActivityTemplateEditorView

/// Editor sheet for ActivityTemplates.
/// Features:
/// - Title (required)
/// - Description (optional)
/// - Audience selection (mutually exclusive - single selection only)
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

        // Audience Section - Mutually Exclusive Selection
        Section {
          VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Who should see this activity?")
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Colors.Text.secondary)

            HStack(spacing: DS.Spacing.sm) {
              ForEach(AudienceSelection.allCases) { audience in
                AudienceChip(
                  audience: audience,
                  isSelected: selectedAudience == audience
                ) {
                  selectAudience(audience)
                }
              }
            }
          }
          .padding(.vertical, DS.Spacing.xs)
        } header: {
          Text("Audience")
        } footer: {
          Text("Each activity can only be visible to one audience.")
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
            selectedAudience = audienceFromRaw(template.audiencesRaw)
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
  @State private var selectedAudience: AudienceSelection = .none
  @State private var defaultAssigneeId: UUID?

  @Query(sort: \User.name)
  private var users: [User]

  private var isEditing: Bool {
    existingTemplate != nil
  }

  private var isValid: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// Converts stored audiencesRaw array to AudienceSelection enum.
  /// Uses normalizeTemplateAudiences to handle legacy multi-audience data.
  private func audienceFromRaw(_ raw: [String]) -> AudienceSelection {
    let normalized = normalizeTemplateAudiences(raw)
    guard let first = normalized.first else {
      return .none
    }
    return AudienceSelection(rawValue: first) ?? .none
  }

  /// Converts AudienceSelection enum to array for storage.
  private func audienceToRaw(_ selection: AudienceSelection) -> [String] {
    switch selection {
    case .none: []
    case .admin: ["admin"]
    case .marketing: ["marketing"]
    }
  }

  /// Selects an audience with haptic feedback
  private func selectAudience(_ audience: AudienceSelection) {
    guard selectedAudience != audience else { return }
    selectedAudience = audience
    HapticFeedback.selection()
  }

  private func save() {
    if let template = existingTemplate {
      // Update existing
      template.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
      template.templateDescription = templateDescription
      template.audiencesRaw = audienceToRaw(selectedAudience)
      template.defaultAssigneeId = defaultAssigneeId
      template.markPending()
    } else {
      // Create new
      let nextPosition = listingType.templates.count
      let template = ActivityTemplate(
        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
        templateDescription: templateDescription,
        position: nextPosition,
        audiencesRaw: audienceToRaw(selectedAudience),
        listingTypeId: listingType.id,
        defaultAssigneeId: defaultAssigneeId
      )
      template.listingType = listingType
      modelContext.insert(template)
      template.markPending()
    }

    syncManager.requestSync()
    dismiss()
  }
}

// MARK: - AudienceChip

/// A chip for selecting an audience. Part of a mutually exclusive group.
/// Only one audience can be selected at a time.
private struct AudienceChip: View {

  // MARK: Internal

  let audience: AudienceSelection
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: DS.Spacing.xxs) {
        if isSelected {
          Image(systemName: "checkmark")
            .font(.system(size: checkmarkSize, weight: .bold))
        }
        Text(audience.displayName)
          .font(DS.Typography.body)
      }
      .foregroundStyle(isSelected ? .white : audience.color)
      .padding(.horizontal, DS.Spacing.md)
      .padding(.vertical, DS.Spacing.sm)
      .background(isSelected ? audience.color : audience.color.opacity(0.15))
      .cornerRadius(DS.Spacing.radiusCard)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(audience.displayName) audience")
    .accessibilityHint(isSelected ? "Selected" : "Tap to select")
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }

  // MARK: Private

  /// Scaled checkmark icon size for Dynamic Type support (base: 10pt)
  @ScaledMetric(relativeTo: .caption2)
  private var checkmarkSize: CGFloat = 10

}

// MARK: - Preview

#Preview {
  PreviewShell { context in
    let saleType = ListingTypeDefinition(
      id: UUID(),
      name: "Sale",
      position: 0,
      ownedBy: UUID()
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
