//
//  DocumentUploadSection.swift
//  Dispatch
//
//  Document upload section for the description generator.
//  Supports uploading PDFs and other documents with type categorization.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - DocumentUploadSection

/// Section for managing uploaded supporting documents.
/// Documents are categorized by type for AI processing context.
struct DocumentUploadSection: View {

  // MARK: Internal

  @Binding var documents: [UploadedDocument]

  let onAdd: (UploadedDocument) -> Void
  let onRemove: (UUID) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.md) {
      // Section header
      sectionHeader

      // Content
      if documents.isEmpty {
        emptyState
      } else {
        documentList
      }
    }
    .padding(DS.Spacing.cardPadding)
    .background(DS.Colors.Background.card)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusCard))
    .sheet(isPresented: $showingTypePicker) {
      DocumentTypePickerSheet(
        selectedType: $pendingDocumentType,
        onConfirm: confirmDocumentUpload,
        onCancel: cancelDocumentUpload
      )
      #if os(macOS)
      .frame(minWidth: 300, minHeight: 250)
      #endif
    }
  }

  // MARK: Private

  @State private var showingFileImporter = false
  @State private var showingTypePicker = false
  @State private var pendingDocumentData: Data?
  @State private var pendingDocumentFilename: String?
  @State private var pendingDocumentType: DocumentType = .other

  private let supportedTypes: [UTType] = [
    .pdf,
    .plainText,
    .rtf,
    UTType(filenameExtension: "doc") ?? .data,
    UTType(filenameExtension: "docx") ?? .data
  ]

  @ViewBuilder
  private var sectionHeader: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
      Text("Documents")
        .font(DS.Typography.headline)
        .foregroundStyle(DS.Colors.Text.primary)

      Text("\(documents.count) document\(documents.count == 1 ? "" : "s")")
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private var emptyState: some View {
    VStack(spacing: DS.Spacing.md) {
      Image(systemName: "doc.text")
        .font(.system(size: 36))
        .foregroundStyle(DS.Colors.Text.tertiary)
        .accessibilityHidden(true)

      Text("Add documents like seller disclosure, surveys, etc.")
        .font(DS.Typography.body)
        .foregroundStyle(DS.Colors.Text.secondary)
        .multilineTextAlignment(.center)

      Button(action: { showingFileImporter = true }) {
        Text("Select Document")
          .font(DS.Typography.headline)
          .frame(maxWidth: .infinity)
          .frame(height: DS.Spacing.minTouchTarget)
      }
      .buttonStyle(.bordered)
      .accessibilityHint("Opens file browser, then prompts for document type")
      .fileImporter(
        isPresented: $showingFileImporter,
        allowedContentTypes: supportedTypes,
        allowsMultipleSelection: false
      ) { result in
        handleFileImport(result)
      }
    }
    .padding(.vertical, DS.Spacing.xl)
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private var documentList: some View {
    VStack(spacing: DS.Spacing.sm) {
      VStack(spacing: 0) {
        ForEach(documents) { document in
          DocumentRow(
            document: document,
            onDelete: { onRemove(document.id) }
          )

          if document.id != documents.last?.id {
            Divider()
              .padding(.leading, 56 + DS.Spacing.md)
          }
        }
      }
      .background(DS.Colors.Background.secondary)
      .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall))

      // Add more documents button
      Button(action: { showingFileImporter = true }) {
        Label("Add Document", systemImage: "plus.circle")
          .font(DS.Typography.body)
          .frame(maxWidth: .infinity)
          .frame(height: DS.Spacing.minTouchTarget)
      }
      .buttonStyle(.bordered)
      .accessibilityLabel("Add another document")
      .accessibilityHint("Opens file browser, then prompts for document type")
      .fileImporter(
        isPresented: $showingFileImporter,
        allowedContentTypes: supportedTypes,
        allowsMultipleSelection: false
      ) { result in
        handleFileImport(result)
      }
    }
  }

  // MARK: - File Handling

  private func handleFileImport(_ result: Result<[URL], Error>) {
    guard
      case .success(let urls) = result,
      let url = urls.first
    else { return }

    guard url.startAccessingSecurityScopedResource() else { return }
    defer { url.stopAccessingSecurityScopedResource() }

    guard let data = try? Data(contentsOf: url) else { return }

    // Store pending data and show type picker
    pendingDocumentData = data
    pendingDocumentFilename = url.lastPathComponent
    pendingDocumentType = inferDocumentType(from: url.lastPathComponent)
    showingTypePicker = true
  }

  private func inferDocumentType(from filename: String) -> DocumentType {
    let lowercased = filename.lowercased()

    if lowercased.contains("disclosure") || lowercased.contains("seller") {
      return .sellerDisclosure
    } else if lowercased.contains("survey") {
      return .propertySurvey
    } else if lowercased.contains("floor") || lowercased.contains("plan") {
      return .floorPlan
    } else if lowercased.contains("hoa") || lowercased.contains("association") {
      return .hoaDocuments
    } else if lowercased.contains("inspection") {
      return .inspectionReport
    }
    return .other
  }

  private func confirmDocumentUpload() {
    guard
      let data = pendingDocumentData,
      let filename = pendingDocumentFilename
    else { return }

    let document = UploadedDocument(
      filename: filename,
      fileType: pendingDocumentType,
      data: data
    )

    onAdd(document)
    clearPendingDocument()
  }

  private func cancelDocumentUpload() {
    clearPendingDocument()
  }

  private func clearPendingDocument() {
    pendingDocumentData = nil
    pendingDocumentFilename = nil
    pendingDocumentType = .other
    showingTypePicker = false
  }
}

// MARK: - DocumentTypePickerSheet

/// Sheet for selecting document type before upload.
struct DocumentTypePickerSheet: View {

  @Binding var selectedType: DocumentType

  let onConfirm: () -> Void
  let onCancel: () -> Void

  var body: some View {
    NavigationStack {
      VStack(spacing: DS.Spacing.lg) {
        Text("Select Document Type")
          .font(DS.Typography.title)
          .padding(.top, DS.Spacing.lg)

        Text("Choose the category that best describes this document")
          .font(DS.Typography.body)
          .foregroundStyle(DS.Colors.Text.secondary)
          .multilineTextAlignment(.center)

        Picker("Document Type", selection: $selectedType) {
          ForEach(DocumentType.allCases) { type in
            Label(type.rawValue, systemImage: type.icon)
              .tag(type)
          }
        }
        .pickerStyle(.inline)
        .labelsHidden()
        .accessibilityLabel("Document type")
        .accessibilityHint("Select the category for this document")

        Spacer()

        HStack(spacing: DS.Spacing.md) {
          Button("Cancel", role: .cancel, action: onCancel)
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            .frame(height: DS.Spacing.minTouchTarget)
            .accessibilityHint("Discards the document without adding")

          Button("Add Document", action: onConfirm)
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .frame(height: DS.Spacing.minTouchTarget)
            .accessibilityHint("Adds the document with the selected type")
        }
        .padding(.bottom, DS.Spacing.lg)
      }
      .padding(.horizontal, DS.Spacing.lg)
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
    }
  }
}

// MARK: - Preview

#Preview("Document Upload - Empty") {
  DocumentUploadSection(
    documents: .constant([]),
    onAdd: { _ in },
    onRemove: { _ in }
  )
  .padding()
  .background(DS.Colors.Background.grouped)
}

#Preview("Document Upload - With Documents") {
  @Previewable @State var documents = [
    UploadedDocument(
      filename: "Seller_Disclosure_2024.pdf",
      fileType: .sellerDisclosure,
      data: Data(repeating: 0, count: 1_234_567)
    ),
    UploadedDocument(
      filename: "Property_Survey.pdf",
      fileType: .propertySurvey,
      data: Data(repeating: 0, count: 512_000)
    )
  ]

  DocumentUploadSection(
    documents: $documents,
    onAdd: { doc in documents.append(doc) },
    onRemove: { id in documents.removeAll { $0.id == id } }
  )
  .padding()
  .background(DS.Colors.Background.grouped)
}

#Preview("Document Type Picker") {
  @Previewable @State var selectedType: DocumentType = .other

  DocumentTypePickerSheet(
    selectedType: $selectedType,
    onConfirm: { },
    onCancel: { }
  )
}
