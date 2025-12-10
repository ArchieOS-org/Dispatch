//
//  UserType.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

enum UserType: String, Codable, CaseIterable {
    case realtor
    case admin
    case marketing
    case exec

    /// Staff members can claim tasks/activities. Only admin and marketing are staff.
    /// Execs have visibility but don't claim work items.
    var isStaff: Bool {
        self == .admin || self == .marketing
    }
}
