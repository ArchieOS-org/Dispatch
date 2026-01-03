//
//  ListingStage.swift
//  Dispatch
//
//  Lifecycle stage for a listing (6 stages)
//

import Foundation

enum ListingStage: String, Codable, CaseIterable {
    case pending
    case workingOn = "working_on"
    case live
    case sold
    case reList = "re_list"
    case done

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .workingOn: return "Working On"
        case .live: return "Live"
        case .sold: return "Sold"
        case .reList: return "Re-List"
        case .done: return "Done"
        }
    }

    var sortOrder: Int {
        switch self {
        case .pending: return 0
        case .workingOn: return 1
        case .live: return 2
        case .sold: return 3
        case .reList: return 4
        case .done: return 5
        }
    }

    /// Fallback decoder - prevents crash on unknown server values
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = ListingStage(rawValue: rawValue) ?? .pending
    }
}
