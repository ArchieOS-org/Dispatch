//
//  ListingGeneratorSnapshot.swift
//  Dispatch
//
//  Codable DTOs for serializing Listing Generator state to SwiftData.
//  Captures all relevant state for draft persistence and restoration.
//

import Foundation

// MARK: - ListingGeneratorInputSnapshot

/// Codable snapshot of input state for draft persistence.
/// Captures property selection, uploads, and report settings.
struct ListingGeneratorInputSnapshot: Codable, Equatable {

  // MARK: - Input Mode

  /// Current input mode (existing listing or manual entry)
  var inputMode: String

  // MARK: - Property Selection

  /// ID of selected listing (when using existing listing mode)
  var selectedListingId: UUID?

  /// Selected listing address (for display without re-fetching)
  var selectedListingAddress: String?

  // MARK: - Manual Entry Fields

  /// Manual property address
  var manualAddress: String

  /// Manual property type description
  var manualPropertyType: String

  /// Manual property details (free-form text)
  var manualDetails: String

  // MARK: - Photos

  /// Uploaded photos (encoded as PhotoSnapshot array)
  var photos: [PhotoSnapshot]

  // MARK: - Documents

  /// Uploaded documents (encoded as DocumentSnapshot array)
  var documents: [DocumentSnapshot]

  // MARK: - Report Settings

  /// Whether GEOWarehouse report is enabled
  var enableGeoWarehouse: Bool

  /// Whether MPAC report is enabled
  var enableMPAC: Bool

  // MARK: - Initialization

  init(
    inputMode: String = "existingListing",
    selectedListingId: UUID? = nil,
    selectedListingAddress: String? = nil,
    manualAddress: String = "",
    manualPropertyType: String = "",
    manualDetails: String = "",
    photos: [PhotoSnapshot] = [],
    documents: [DocumentSnapshot] = [],
    enableGeoWarehouse: Bool = false,
    enableMPAC: Bool = false
  ) {
    self.inputMode = inputMode
    self.selectedListingId = selectedListingId
    self.selectedListingAddress = selectedListingAddress
    self.manualAddress = manualAddress
    self.manualPropertyType = manualPropertyType
    self.manualDetails = manualDetails
    self.photos = photos
    self.documents = documents
    self.enableGeoWarehouse = enableGeoWarehouse
    self.enableMPAC = enableMPAC
  }
}

// MARK: - ListingGeneratorOutputSnapshot

/// Codable snapshot of output state for draft persistence.
/// Captures generated outputs, selections, and refinement history.
struct ListingGeneratorOutputSnapshot: Codable, Equatable {

  // MARK: - Generated Outputs

  /// Output version A (professional tone)
  var outputA: GeneratedOutputSnapshot?

  /// Output version B (warm tone)
  var outputB: GeneratedOutputSnapshot?

  /// Currently selected version ("a" or "b")
  var selectedVersion: String?

  // MARK: - Refinement History

  /// History of refinement requests
  var refinementHistory: [RefinementSnapshot]

  // MARK: - Legacy Fields

  /// Legacy generated description (for backward compatibility)
  var generatedDescription: String

  /// Current status
  var status: String

  // MARK: - Session

  /// Session ID for this generation
  var sessionId: UUID

  // MARK: - Report Integration

  /// Reports that were fetched during generation
  var fetchedReports: [FetchedReportSnapshot]

  /// Whether information was extracted from uploaded photos
  var extractedFromImages: Bool

  // MARK: - Initialization

  init(
    outputA: GeneratedOutputSnapshot? = nil,
    outputB: GeneratedOutputSnapshot? = nil,
    selectedVersion: String? = nil,
    refinementHistory: [RefinementSnapshot] = [],
    generatedDescription: String = "",
    status: String = "draft",
    sessionId: UUID = UUID(),
    fetchedReports: [FetchedReportSnapshot] = [],
    extractedFromImages: Bool = false
  ) {
    self.outputA = outputA
    self.outputB = outputB
    self.selectedVersion = selectedVersion
    self.refinementHistory = refinementHistory
    self.generatedDescription = generatedDescription
    self.status = status
    self.sessionId = sessionId
    self.fetchedReports = fetchedReports
    self.extractedFromImages = extractedFromImages
  }
}

// MARK: - PhotoSnapshot

/// Codable snapshot of an uploaded photo.
struct PhotoSnapshot: Codable, Equatable {
  var id: UUID
  var imageData: Data
  var filename: String
  var sortOrder: Int

  init(from photo: UploadedPhoto) {
    id = photo.id
    imageData = photo.imageData
    filename = photo.filename
    sortOrder = photo.sortOrder
  }

  func toUploadedPhoto() -> UploadedPhoto {
    UploadedPhoto(
      id: id,
      imageData: imageData,
      filename: filename,
      sortOrder: sortOrder
    )
  }
}

// MARK: - DocumentSnapshot

/// Codable snapshot of an uploaded document.
struct DocumentSnapshot: Codable, Equatable {
  var id: UUID
  var filename: String
  var fileType: String
  var data: Data

  init(from document: UploadedDocument) {
    id = document.id
    filename = document.filename
    fileType = document.fileType.rawValue
    data = document.data
  }

  func toUploadedDocument() -> UploadedDocument {
    UploadedDocument(
      id: id,
      filename: filename,
      fileType: DocumentType(rawValue: fileType) ?? .other,
      data: data
    )
  }
}

// MARK: - GeneratedOutputSnapshot

/// Codable snapshot of a generated output.
struct GeneratedOutputSnapshot: Codable, Equatable {
  var id: UUID
  var version: String
  var mlsFields: MLSFieldsSnapshot
  var generatedAt: Date
  var isSelected: Bool

  init(from output: GeneratedOutput) {
    id = output.id
    version = output.version.rawValue
    mlsFields = MLSFieldsSnapshot(from: output.mlsFields)
    generatedAt = output.generatedAt
    isSelected = output.isSelected
  }

  func toGeneratedOutput() -> GeneratedOutput {
    let outputVersion: OutputVersion = version == OutputVersion.a.rawValue ? .a : .b
    return GeneratedOutput(
      id: id,
      version: outputVersion,
      mlsFields: mlsFields.toMLSFields(),
      generatedAt: generatedAt,
      isSelected: isSelected
    )
  }
}

// MARK: - MLSFieldsSnapshot

/// Codable snapshot of MLS fields.
struct MLSFieldsSnapshot: Codable, Equatable {
  // Property Details
  var propertyType: String
  var yearBuilt: String
  var squareFootage: String
  var lotSize: String
  var bedrooms: String
  var bathrooms: String
  var stories: String
  var parkingSpaces: String
  var garageType: String

  // Features
  var heatingCooling: String
  var flooring: String
  var appliances: String
  var exteriorFeatures: String
  var interiorFeatures: String
  var communityFeatures: String

  // Descriptions
  var publicRemarks: String
  var privateRemarks: String
  var directions: String

  // Marketing
  var headline: String
  var tagline: String

  init(from fields: MLSFields) {
    propertyType = fields.propertyType
    yearBuilt = fields.yearBuilt
    squareFootage = fields.squareFootage
    lotSize = fields.lotSize
    bedrooms = fields.bedrooms
    bathrooms = fields.bathrooms
    stories = fields.stories
    parkingSpaces = fields.parkingSpaces
    garageType = fields.garageType
    heatingCooling = fields.heatingCooling
    flooring = fields.flooring
    appliances = fields.appliances
    exteriorFeatures = fields.exteriorFeatures
    interiorFeatures = fields.interiorFeatures
    communityFeatures = fields.communityFeatures
    publicRemarks = fields.publicRemarks
    privateRemarks = fields.privateRemarks
    directions = fields.directions
    headline = fields.headline
    tagline = fields.tagline
  }

  func toMLSFields() -> MLSFields {
    var fields = MLSFields()
    fields.propertyType = propertyType
    fields.yearBuilt = yearBuilt
    fields.squareFootage = squareFootage
    fields.lotSize = lotSize
    fields.bedrooms = bedrooms
    fields.bathrooms = bathrooms
    fields.stories = stories
    fields.parkingSpaces = parkingSpaces
    fields.garageType = garageType
    fields.heatingCooling = heatingCooling
    fields.flooring = flooring
    fields.appliances = appliances
    fields.exteriorFeatures = exteriorFeatures
    fields.interiorFeatures = interiorFeatures
    fields.communityFeatures = communityFeatures
    fields.publicRemarks = publicRemarks
    fields.privateRemarks = privateRemarks
    fields.directions = directions
    fields.headline = headline
    fields.tagline = tagline
    return fields
  }
}

// MARK: - RefinementSnapshot

/// Codable snapshot of a refinement request.
struct RefinementSnapshot: Codable, Equatable {
  var id: UUID
  var prompt: String
  var timestamp: Date

  init(from request: RefinementRequest) {
    id = request.id
    prompt = request.prompt
    timestamp = request.timestamp
  }

  func toRefinementRequest() -> RefinementRequest {
    RefinementRequest(
      id: id,
      prompt: prompt,
      timestamp: timestamp
    )
  }
}

// MARK: - FetchedReportSnapshot

/// Codable snapshot of a fetched report.
struct FetchedReportSnapshot: Codable, Equatable {
  var id: UUID
  var type: String
  var fetchedAt: Date
  var isExpanded: Bool
  var mockSummary: String

  init(from report: FetchedReport) {
    id = report.id
    type = report.type.rawValue
    fetchedAt = report.fetchedAt
    isExpanded = report.isExpanded
    mockSummary = report.mockSummary
  }

  func toFetchedReport() -> FetchedReport {
    FetchedReport(
      id: id,
      type: ReportType(rawValue: type) ?? .geoWarehouse,
      fetchedAt: fetchedAt,
      isExpanded: isExpanded,
      mockSummary: mockSummary
    )
  }
}
