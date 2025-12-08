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

    private var rank: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        case .urgent: return 3
        }
    }

    static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.rank < rhs.rank
    }
}
