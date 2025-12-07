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

    static func < (lhs: Priority, rhs: Priority) -> Bool {
        let order: [Priority] = [.low, .medium, .high, .urgent]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}
