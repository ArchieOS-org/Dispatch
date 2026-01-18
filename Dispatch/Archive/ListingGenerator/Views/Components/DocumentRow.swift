//
//  DocumentRow.swift
//  Dispatch
//
//  Document list item component for the description generator.
//  Displays document icon, filename, type badge, and delete button.
//

import SwiftUI

// MARK: - DocumentRow

/// A single row displaying an uploaded document.
/// Shows file icon, name, type badge, size, and delete action.
struct DocumentRow: View {

  // MARK: Internal

  let document: UploadedDocument
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: DS.Spacing.md) {
      // Document icon
      documentIcon

      // Document info
      VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
        Text(document.filename)
          .font(DS.Typography.headline)
          .foregroundStyle(DS.Colors.Text.primary)
          .lineLimit(1)

        HStack(spacing: DS.Spacing.sm) {
          // Type badge
          DocumentTypeBadge(type: document.fileType)

          // File size
          Text(document.formattedSize)
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Colors.Text.tertiary)
        }
      }

      Spacer()

      // Delete button
      Button(action: onDelete) {
        Image(systemName: DS.Icons.Action.delete)
          .font(DS.Typography.body)
          .foregroundStyle(DS.Colors.Text.tertiary)
      }
      .buttonStyle(.plain)
      .frame(width: DS.Spacing.minTouchTarget, height: DS.Spacing.minTouchTarget)
      .contentShape(Rectangle())
      .accessibilityLabel("Delete document")
    }
    .padding(.vertical, DS.Spacing.sm)
    .padding(.horizontal, DS.Spacing.md)
    .background(DS.Colors.Background.card)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(document.filename), \(document.fileType.rawValue), \(document.formattedSize)")
    .accessibilityAction(named: "Delete") {
      onDelete()
    }
  }

  // MARK: Private

  @ViewBuilder
  private var documentIcon: some View {
    Image(systemName: document.fileType.icon)
      .font(.system(size: 24))
      .foregroundStyle(DS.Colors.accent)
      .frame(width: 40, height: 40)
      .background(DS.Colors.accent.opacity(0.1))
      .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall))
  }
}

// MARK: - DocumentTypeBadge

/// Small pill badge showing document type category.
struct DocumentTypeBadge: View {

  // MARK: Internal

  let type: DocumentType

  var body: some View {
    Text(type.rawValue)
      .font(DS.Typography.captionSecondary)
      .fontWeight(.medium)
      .foregroundStyle(badgeColor)
      .padding(.horizontal, DS.Spacing.sm)
      .padding(.vertical, DS.Spacing.xxs)
      .background(badgeColor.opacity(0.12))
      .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall))
  }

  // MARK: Private

  private var badgeColor: Color {
    switch type {
    case .sellerDisclosure: DS.Colors.warning
    case .propertySurvey: DS.Colors.info
    case .floorPlan: Color.purple
    case .hoaDocuments: DS.Colors.success
    case .inspectionReport: DS.Colors.destructive
    case .other: DS.Colors.Text.secondary
    }
  }
}

// MARK: - Preview

#Preview("Document Row") {
  VStack(spacing: 0) {
    DocumentRow(
      document: UploadedDocument(
        filename: "Seller_Disclosure_2024.pdf",
        fileType: .sellerDisclosure,
        data: Data(repeating: 0, count: 1_234_567)
      ),
      onDelete: { }
    )

    Divider()
      .padding(.leading, 56 + DS.Spacing.md)

    DocumentRow(
      document: UploadedDocument(
        filename: "Property_Survey.pdf",
        fileType: .propertySurvey,
        data: Data(repeating: 0, count: 512_000)
      ),
      onDelete: { }
    )

    Divider()
      .padding(.leading, 56 + DS.Spacing.md)

    DocumentRow(
      document: UploadedDocument(
        filename: "Floor_Plans.pdf",
        fileType: .floorPlan,
        data: Data(repeating: 0, count: 2_048_000)
      ),
      onDelete: { }
    )
  }
  .background(DS.Colors.Background.grouped)
}

#Preview("Document Type Badges") {
  HStack(spacing: DS.Spacing.sm) {
    ForEach(DocumentType.allCases) { type in
      DocumentTypeBadge(type: type)
    }
  }
  .padding()
}
