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

    var displayName: String {
        switch self {
        case .residential: return "Residential"
        case .commercial: return "Commercial"
        case .land: return "Land"
        case .multiFamily: return "Multi-Family"
        case .condo: return "Condo"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .residential: return "house"
        case .commercial: return "building.2"
        case .land: return "leaf"
        case .multiFamily: return "building"
        case .condo: return "building.columns"
        case .other: return "square.grid.2x2"
        }
    }

    /// Fallback decoder - prevents crash on unknown server values
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = PropertyType(rawValue: rawValue) ?? .residential
    }
}
