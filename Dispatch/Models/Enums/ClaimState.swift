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

    var isClaimed: Bool {
        switch self {
        case .unclaimed: return false
        case .claimedByMe, .claimedByOther: return true
        }
    }

    var canClaim: Bool {
        switch self {
        case .unclaimed: return true
        case .claimedByMe, .claimedByOther: return false
        }
    }

    var canRelease: Bool {
        switch self {
        case .claimedByMe: return true
        case .unclaimed, .claimedByOther: return false
        }
    }
}
