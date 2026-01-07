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

  // MARK: Lifecycle

  /// Fallback decoder - prevents crash on unknown server values
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self = ListingStage(rawValue: rawValue) ?? .pending
  }

  // MARK: Internal

  var displayName: String {
    switch self {
    case .pending: "Pending"
    case .workingOn: "Working On"
    case .live: "Live"
    case .sold: "Sold"
    case .reList: "Re-List"
    case .done: "Done"
    }
  }

  var sortOrder: Int {
    switch self {
    case .pending: 0
    case .workingOn: 1
    case .live: 2
    case .sold: 3
    case .reList: 4
    case .done: 5
    }
  }

}
