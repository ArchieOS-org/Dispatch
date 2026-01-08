//
//  ClaimState.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

/// Represents the claim state of a work item relative to the current user.
/// Used for UI display to determine which actions are available.
/// Not Codable because it contains SwiftData model references.
enum ClaimState {
  case unclaimed
  case claimedByMe(user: User)
  case claimedByOther(user: User)

  // MARK: Internal

  var isClaimed: Bool {
    switch self {
    case .unclaimed: false
    case .claimedByMe, .claimedByOther: true
    }
  }

  var canClaim: Bool {
    switch self {
    case .unclaimed: true
    case .claimedByMe, .claimedByOther: false
    }
  }

  var canRelease: Bool {
    switch self {
    case .claimedByMe: true
    case .unclaimed, .claimedByOther: false
    }
  }
}
