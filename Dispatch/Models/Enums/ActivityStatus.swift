//
//  ActivityStatus.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

enum ActivityStatus: String, Codable, CaseIterable {
    case open
    case inProgress = "in_progress"
    case completed
    case deleted
}
