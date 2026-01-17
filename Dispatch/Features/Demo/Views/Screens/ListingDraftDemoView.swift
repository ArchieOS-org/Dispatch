//
//  ListingDraftDemoView.swift
//  Dispatch
//
//  Demo view for listing draft editing.
//  Designed as an active editing interface for slide deck presentation.
//  Self-contained with sample data - no real data connections.
//

import SwiftUI

// MARK: - ListingDraftDemoView

struct ListingDraftDemoView: View {

  // MARK: Internal

  var body: some View {
    StandardScreen(title: "Edit Draft", layout: .column, scroll: .automatic) {
      content
    } toolbarContent: {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
          dismiss()
        }
      }

      ToolbarItem(placement: .primaryAction) {
        HStack(spacing: DS.Spacing.xs) {
          // Unsaved changes indicator
          if draft.isDirty {
            Circle()
              .fill(DS.Colors.accent)
              .frame(width: 8, height: 8)
          }

          Button("Save") {
            // Demo only - just dismiss
            dismiss()
          }
          .fontWeight(.semibold)
        }
      }
    }
    .alert("Add Feature", isPresented: $showAddFeatureAlert) {
      TextField("Feature", text: $newFeatureText)
      Button("Cancel", role: .cancel) {
        newFeatureText = ""
      }
      Button("Add") {
        if !newFeatureText.isEmpty {
          draft.addFeature(newFeatureText)
          newFeatureText = ""
        }
      }
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @State private var draft = DemoListingDraft.sample()
  @State private var showAddFeatureAlert = false
  @State private var newFeatureText = ""

  private var isCompact: Bool {
    horizontalSizeClass == .compact
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.xl) {
      // Photos Section
      photosSection

      Divider()

      // Stage Section
      stageSection

      Divider()

      // Property Details Section
      propertyDetailsSection

      Divider()

      // Listing Information Section
      listingInfoSection

      Divider()

      // Description Section
      descriptionSection

      Divider()

      // Features Section
      featuresSection
    }
    .padding(.bottom, DS.Spacing.xxl)
  }

  // MARK: - Photos Section

  private var photosSection: some View {
    DraftPhotoGallery(
      photos: $draft.photos,
      onAddPhoto: {
        // Demo only - no actual photo picker
      }
    )
  }

  // MARK: - Stage Section

  private var stageSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      Text("Stage")
        .font(DS.Typography.headline)
        .foregroundStyle(DS.Colors.Text.primary)

      StagePicker(
        stage: $draft.stage,
        horizontalInset: 0
      )
    }
  }

  // MARK: - Property Details Section

  private var propertyDetailsSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.md) {
      Text("Property Details")
        .font(DS.Typography.headline)
        .foregroundStyle(DS.Colors.Text.primary)

      VStack(alignment: .leading, spacing: DS.Spacing.md) {
        // Address
        LabeledTextField(label: "Address", text: $draft.address)

        // Unit
        LabeledTextField(label: "Unit", text: $draft.unit)

        // City and Province row
        if isCompact {
          LabeledTextField(label: "City", text: $draft.city)
          HStack(spacing: DS.Spacing.md) {
            LabeledTextField(label: "Province", text: $draft.province)
              .frame(maxWidth: 100)
            LabeledTextField(label: "Postal Code", text: $draft.postalCode)
              .frame(maxWidth: 120)
            Spacer()
          }
        } else {
          HStack(spacing: DS.Spacing.md) {
            LabeledTextField(label: "City", text: $draft.city)
            LabeledTextField(label: "Province", text: $draft.province)
              .frame(maxWidth: 100)
            LabeledTextField(label: "Postal Code", text: $draft.postalCode)
              .frame(maxWidth: 120)
          }
        }
      }
    }
  }

  // MARK: - Listing Information Section

  private var listingInfoSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.md) {
      Text("Listing Information")
        .font(DS.Typography.headline)
        .foregroundStyle(DS.Colors.Text.primary)

      // Price
      VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        Text("Price")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.secondary)

        TextField("Price", value: $draft.price, format: .currency(code: "CAD"))
          .textFieldStyle(.roundedBorder)
        #if os(iOS)
          .keyboardType(.decimalPad)
        #endif
      }

      // Listing Type
      VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        Text("Type")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.secondary)

        Picker("Type", selection: $draft.listingType) {
          ForEach(DemoListingType.allCases) { type in
            Text(type.rawValue).tag(type)
          }
        }
        .pickerStyle(.segmented)
      }

      // Stats Row (Beds, Baths, Sq Ft)
      HStack(spacing: DS.Spacing.lg) {
        StatStepper(label: "Beds", value: $draft.bedrooms, range: 0 ... 20)
        StatStepper(label: "Baths", value: $draft.bathrooms, range: 0 ... 10)
        StatStepper(label: "Sq Ft", value: $draft.squareFeet, range: 0 ... 50000, step: 50)
      }
    }
  }

  // MARK: - Description Section

  private var descriptionSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      Text("Description")
        .font(DS.Typography.headline)
        .foregroundStyle(DS.Colors.Text.primary)

      // Headline
      LabeledTextField(label: "Headline", text: $draft.headline)

      // Full description
      VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        Text("Details")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.secondary)

        TextEditor(text: $draft.description)
          .font(DS.Typography.body)
          .frame(minHeight: 150)
          .padding(DS.Spacing.sm)
          .background(DS.Colors.Background.secondary)
          .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall))
          .overlay(
            RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall)
              .stroke(DS.Colors.border, lineWidth: 1)
          )
      }
    }
  }

  // MARK: - Features Section

  private var featuresSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      HStack {
        Text("Features")
          .font(DS.Typography.headline)
          .foregroundStyle(DS.Colors.Text.primary)

        Text("(\(draft.features.count))")
          .font(DS.Typography.bodySecondary)
          .foregroundStyle(DS.Colors.Text.secondary)

        Spacer()

        Button {
          showAddFeatureAlert = true
        } label: {
          Label("Add", systemImage: "plus")
            .font(DS.Typography.body)
        }
      }

      VStack(spacing: DS.Spacing.xs) {
        ForEach(Array(draft.features.enumerated()), id: \.offset) { index, feature in
          FeatureRow(
            feature: feature,
            onDelete: {
              withAnimation {
                draft.removeFeature(at: index)
              }
            }
          )
        }
      }
    }
  }

}

// MARK: - LabeledTextField

private struct LabeledTextField: View {
  let label: String
  @Binding var text: String

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
      Text(label)
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.secondary)

      TextField(label, text: $text)
        .textFieldStyle(.roundedBorder)
    }
  }
}

// MARK: - StatStepper

private struct StatStepper: View {
  let label: String
  @Binding var value: Int
  let range: ClosedRange<Int>
  var step: Int = 1

  var body: some View {
    VStack(spacing: DS.Spacing.xs) {
      Text("\(value)")
        .font(DS.Typography.title)
        .foregroundStyle(DS.Colors.Text.primary)
        .monospacedDigit()

      Text(label)
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.secondary)

      HStack(spacing: DS.Spacing.sm) {
        Button {
          if value - step >= range.lowerBound {
            value -= step
          }
        } label: {
          Image(systemName: "minus.circle.fill")
            .font(.title2)
            .foregroundStyle(value > range.lowerBound ? DS.Colors.accent : DS.Colors.Text.disabled)
        }
        .disabled(value <= range.lowerBound)

        Button {
          if value + step <= range.upperBound {
            value += step
          }
        } label: {
          Image(systemName: "plus.circle.fill")
            .font(.title2)
            .foregroundStyle(value < range.upperBound ? DS.Colors.accent : DS.Colors.Text.disabled)
        }
        .disabled(value >= range.upperBound)
      }
      .buttonStyle(.plain)
    }
    .frame(maxWidth: .infinity)
    .padding(DS.Spacing.md)
    .background(DS.Colors.Background.secondary)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium))
  }
}

// MARK: - FeatureRow

private struct FeatureRow: View {
  let feature: String
  let onDelete: () -> Void

  var body: some View {
    HStack {
      Text(feature)
        .font(DS.Typography.body)
        .foregroundStyle(DS.Colors.Text.primary)

      Spacer()

      Button {
        onDelete()
      } label: {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(DS.Colors.Text.tertiary)
      }
      .buttonStyle(.plain)
    }
    .padding(DS.Spacing.md)
    .background(DS.Colors.Background.secondary)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall))
  }
}

// MARK: - Previews

#Preview("Draft Editor - iPhone") {
  NavigationStack {
    ListingDraftDemoView()
  }
}

#Preview("Draft Editor - iPad", traits: .landscapeLeft) {
  NavigationStack {
    ListingDraftDemoView()
  }
}
