//
//  ReportIntegration.swift
//  Dispatch
//
//  Types supporting report integration for the Description Generator.
//  Includes report type selection, generation phases, and fetched report data.
//

import Foundation

// MARK: - ReportType

/// Types of property reports that can be fetched for description generation.
enum ReportType: String, CaseIterable, Identifiable {
  /// GEOWarehouse property report
  case geoWarehouse
  /// MPAC property assessment report
  case mpac

  // MARK: Internal

  var id: String { rawValue }

  /// Display name for the report type
  var displayName: String {
    switch self {
    case .geoWarehouse: "GEOWarehouse"
    case .mpac: "MPAC"
    }
  }

  /// SF Symbol icon for the report type
  var icon: String {
    switch self {
    case .geoWarehouse: "map"
    case .mpac: "building.columns"
    }
  }
}

// MARK: - GenerationPhase

/// Tracks the current phase of the description generation process.
enum GenerationPhase: Equatable {
  /// No generation in progress
  case idle
  /// Fetching a specific report type
  case fetchingReport(ReportType)
  /// Extracting information from uploaded photos
  case extractingFromImages
  /// Generating the dual descriptions
  case generatingDescriptions
  /// Generation complete
  case complete

  // MARK: Internal

  /// Display text for the current phase
  var displayText: String {
    switch self {
    case .idle:
      ""
    case .fetchingReport(let reportType):
      "Obtaining \(reportType.displayName)..."
    case .extractingFromImages:
      "Extracting from photos..."
    case .generatingDescriptions:
      "Generating descriptions..."
    case .complete:
      "Complete"
    }
  }

  /// Whether this phase shows progress (spinner)
  var showsProgress: Bool {
    switch self {
    case .idle, .complete:
      false
    case .fetchingReport, .extractingFromImages, .generatingDescriptions:
      true
    }
  }
}

// MARK: - FetchedReport

/// Represents a report that was fetched during generation.
struct FetchedReport: Identifiable, Equatable {

  // MARK: Lifecycle

  init(
    id: UUID = UUID(),
    type: ReportType,
    fetchedAt: Date = Date(),
    isExpanded: Bool = false,
    mockSummary: String? = nil
  ) {
    self.id = id
    self.type = type
    self.fetchedAt = fetchedAt
    self.isExpanded = isExpanded
    self.mockSummary = mockSummary ?? Self.defaultSummary(for: type)
  }

  // MARK: Internal

  /// Unique identifier
  let id: UUID

  /// The type of report
  let type: ReportType

  /// When the report was fetched
  let fetchedAt: Date

  /// Whether the report details are expanded in the UI
  var isExpanded: Bool

  /// Mock summary content for display
  /// PHASE 3: Replace with real report data
  let mockSummary: String

  /// Default mock summary for a report type
  static func defaultSummary(for type: ReportType) -> String {
    switch type {
    case .geoWarehouse:
      """
      Property located in residential zone R-3. Lot dimensions: 50' x 120'.
      Flood zone: None. Environmental considerations: None identified.
      Nearby amenities include schools within 1km and public transit access.
      """
    case .mpac:
      """
      Current assessed value: $485,000. Assessment year: 2024.
      Property class: Residential. Roll number: 1904-010-015-12300.
      Total area: 2,450 sq ft. Year built: 2015.
      """
    }
  }
}
