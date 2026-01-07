//
//  ClaimableProtocol.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

// MARK: - ClaimableProtocol

protocol ClaimableProtocol {
  var claimedBy: UUID? { get set }
  var claimHistory: [ClaimEvent] { get }
  var claimedAt: Date? { get set }

  var canBeClaimed: Bool { get }
}

extension ClaimableProtocol {
  var canBeClaimed: Bool {
    claimedBy == nil
  }
}
