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
    case `operator`
    case exec

    /// Staff members can claim tasks/activities. Only admin, marketing, and operator are staff.
    /// Execs have visibility but don't claim work items.
    var isStaff: Bool {
        self == .admin || self == .marketing || self == .operator
    }
}
