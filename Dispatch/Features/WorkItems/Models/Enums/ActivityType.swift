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
}
