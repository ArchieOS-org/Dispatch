//
//  SyncStatus.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

enum SyncStatus: String, Codable, CaseIterable {
    case synced
    case pending
    case error
    case syncing
}
