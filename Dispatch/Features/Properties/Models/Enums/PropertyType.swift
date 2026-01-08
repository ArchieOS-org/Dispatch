//
//  PropertyType.swift
//  Dispatch
//
//  Property classification types
//

import Foundation

enum PropertyType: String, Codable, CaseIterable {
  case residential
  case commercial
  case land
  case multiFamily = "multi_family"
  case condo
  case other

  // MARK: Lifecycle

  /// Fallback decoder - prevents crash on unknown server values
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self = PropertyType(rawValue: rawValue) ?? .residential
  }

  // MARK: Internal

  var displayName: String {
    switch self {
    case .residential: "Residential"
    case .commercial: "Commercial"
    case .land: "Land"
    case .multiFamily: "Multi-Family"
    case .condo: "Condo"
    case .other: "Other"
    }
  }

  var icon: String {
    switch self {
    case .residential: "house"
    case .commercial: "building.2"
    case .land: "leaf"
    case .multiFamily: "building"
    case .condo: "building.columns"
    case .other: "square.grid.2x2"
    }
  }

}
