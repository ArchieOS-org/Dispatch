//
//  ListingTypeDetailView.swift
//  Dispatch
//
//  Detail view for editing a ListingTypeDefinition and its templates.
//  Part of Listing Types & Activity Templates feature.
//

import SwiftData
import SwiftUI

// MARK: - ListingTypeDetailView

/// Detail view showing a ListingType and its associated ActivityTemplates.
struct ListingTypeDetailView: View {

  // MARK: Internal

  let listingType: ListingTypeDefinition

  var body: some View {
    StandardScreen(title: listingType.name, layout: .column, scroll: .disabled) {
      VStack(spacing: 0) {
        // Header: Type Name Editor (if not system)
        if !listingType.isSystem {
          typeNameSection
        }

        // Templates List
        templatesSection
      }
    } toolbarContent: {
      ToolbarItem(placement: .primaryAction) {
        Button {
          showAddTemplateSheet = true
        } label: {
          Image(systemName: "plus")
        }
      }
    }
    .onAppear {
      editedName = listingType.name
    }
    .sheet(isPresented: $showAddTemplateSheet) {
      ActivityTemplateEditorView(listingType: listingType)
    }
    .sheet(item: $selectedTemplate) { template in
      ActivityTemplateEditorView(listingType: listingType, existingTemplate: template)
    }
  }

  // MARK: Private

  @EnvironmentObject private var syncManager: SyncManager
  @Environment(\.modelContext) private var modelContext

  @State private var editedName = ""
  @State private var showAddTemplateSheet = false
  @State private var selectedTemplate: ActivityTemplate?

  /// Templates sorted by position
  private var sortedTemplates: [ActivityTemplate] {
    listingType.templates
      .filter { !$0.isArchived }
      .sorted { $0.position < $1.position }
  }

  private var typeNameSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      Text("Type Name")
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.secondary)

      HStack {
        TextField("Name", text: $editedName)
          .textFieldStyle(.roundedBorder)

        if editedName != listingType.name {
          Button("Save") {
            saveTypeName()
          }
          .buttonStyle(.borderedProminent)
        }
      }
    }
    .padding(DS.Spacing.md)
    .background(DS.Colors.Background.secondary)
  }

  private var templatesSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      HStack {
        Text("Activity Templates")
          .font(DS.Typography.headline)
          .foregroundStyle(DS.Colors.Text.primary)

        Spacer()

        Text("\(sortedTemplates.count)")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.tertiary)
      }
      .padding(.horizontal, DS.Spacing.md)
      .padding(.top, DS.Spacing.md)

      if sortedTemplates.isEmpty {
        VStack {
          Spacer()
          ContentUnavailableView {
            Label("No Templates", systemImage: "doc.text")
          } description: {
            Text("Add templates to auto-generate activities.")
          }
          Spacer()
        }
      } else {
        List {
          ForEach(sortedTemplates) { template in
            Button {
              selectedTemplate = template
            } label: {
              ActivityTemplateRow(template: template)
            }
            .buttonStyle(.plain)
          }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 1)
      }
    }
  }

  private func saveTypeName() {
    listingType.name = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
    listingType.markPending()
    syncManager.requestSync()
  }
}

// MARK: - ActivityTemplateRow

private struct ActivityTemplateRow: View {
  let template: ActivityTemplate

  var body: some View {
    HStack(spacing: DS.Spacing.md) {
      VStack(alignment: .leading, spacing: 2) {
        Text(template.title)
          .font(DS.Typography.body)
          .foregroundStyle(DS.Colors.Text.primary)

        HStack(spacing: DS.Spacing.xs) {
          ForEach(template.audiencesRaw, id: \.self) { audience in
            AudienceChip(audience: audience)
          }
        }
      }

      Spacer()

      Image(systemName: DS.Icons.Navigation.forward)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(DS.Colors.Text.tertiary)
    }
    .padding(.vertical, DS.Spacing.listRowPadding)
    .contentShape(Rectangle())
  }
}

// MARK: - AudienceChip

private struct AudienceChip: View {

  // MARK: Internal

  let audience: String

  var body: some View {
    Text(audience.capitalized)
      .font(DS.Typography.caption)
      .foregroundStyle(color)
      .padding(.horizontal, DS.Spacing.xs)
      .padding(.vertical, 2)
      .background(color.opacity(0.15))
      .cornerRadius(DS.Spacing.radiusSmall)
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

    let template = ActivityTemplate(
      title: "Order Photos",
      templateDescription: "Hire photographer for listing photos",
      audiencesRaw: ["marketing"],
      listingTypeId: saleType.id,
    )
    template.listingType = saleType
    context.insert(template)
  } content: { context in
    let saleType = try! context.fetch(FetchDescriptor<ListingTypeDefinition>()).first!
    ListingTypeDetailView(listingType: saleType)
  }
}
