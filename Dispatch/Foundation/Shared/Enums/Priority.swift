//
//  Priority.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

enum Priority: String, Codable, CaseIterable, Comparable {
  case low
  case medium
  case high
  case urgent

  static func <(lhs: Priority, rhs: Priority) -> Bool {
    lhs.rank < rhs.rank
  }

  private var rank: Int {
    switch self {
    case .low: 0
    case .medium: 1
    case .high: 2
    case .urgent: 3
    }
  }

}
