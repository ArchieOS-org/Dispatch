//
//  ActivityType.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

enum ActivityType: String, Codable, CaseIterable {
  case call
  case email
  case meeting
  case showProperty = "show_property"
  case followUp = "follow_up"
  case other

  var displayName: String {
    switch self {
    case .call: "Phone Call"
    case .email: "Email"
    case .meeting: "Meeting"
    case .showProperty: "Show Property"
    case .followUp: "Follow Up"
    case .other: "Other"
    }
  }
}
