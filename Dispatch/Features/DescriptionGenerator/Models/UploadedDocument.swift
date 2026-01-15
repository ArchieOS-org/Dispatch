//
//  UploadedDocument.swift
//  Dispatch
//
//  Document model for supporting files in description generation.
//  Supports categorization by document type.
//

import Foundation

// MARK: - DocumentType

/// Categories of supporting documents for listing descriptions.
enum DocumentType: String, CaseIterable, Identifiable {
  case sellerDisclosure = "Seller Disclosure"
  case propertySurvey = "Property Survey"
  case floorPlan = "Floor Plan"
  case hoaDocuments = "HOA Documents"
  case inspectionReport = "Inspection Report"
  case other = "Other"

  // MARK: Internal

  var id: String { rawValue }

  /// SF Symbol icon for this document type
  var icon: String {
    switch self {
    case .sellerDisclosure: "doc.text"
    case .propertySurvey: "map"
    case .floorPlan: "square.grid.3x3"
    case .hoaDocuments: "building.2"
    case .inspectionReport: "checklist"
    case .other: "doc"
    }
  }
}

// MARK: - UploadedDocument

/// A document uploaded to support AI description generation.
/// PHASE 3: AI will extract text and information from documents.
struct UploadedDocument: Identifiable, Equatable {

  // MARK: Lifecycle

  // MARK: - Initialization

  init(
    id: UUID = UUID(),
    filename: String,
    fileType: DocumentType,
    data: Data
  ) {
    self.id = id
    self.filename = filename
    self.fileType = fileType
    self.data = data
  }

  // MARK: Internal

  // MARK: - Properties

  /// Unique identifier for the document
  let id: UUID

  /// Original filename of the uploaded document
  let filename: String

  /// Category of this document
  let fileType: DocumentType

  /// Raw document data
  let data: Data

  // MARK: - Computed Properties

  /// File size formatted for display
  var formattedSize: String {
    ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
  }

  // MARK: - Equatable

  static func ==(lhs: UploadedDocument, rhs: UploadedDocument) -> Bool {
    lhs.id == rhs.id &&
      lhs.filename == rhs.filename &&
      lhs.fileType == rhs.fileType &&
      lhs.data == rhs.data
  }
}
