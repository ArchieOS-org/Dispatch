//
//  ListingStatus.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

enum ListingStatus: String, Codable, CaseIterable {
    case draft
    case active
    case pending
    case closed
    case deleted

    var displayName: String {
        rawValue.capitalized
    }
}
