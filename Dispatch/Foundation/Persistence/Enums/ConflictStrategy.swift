//
//  ConflictStrategy.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

enum ConflictStrategy: String, Codable, CaseIterable {
    case lastWriteWins = "last_write_wins"
    case serverWins = "server_wins"
    case manual
}
