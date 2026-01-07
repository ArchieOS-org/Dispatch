//
//  Listing+StageCounts.swift
//  Dispatch
//
//  Extension for computing stage counts from a collection of listings.
//

import Foundation

extension Array where Element == Listing {
    /// Computes stage counts in a single pass - no intermediate allocation.
    /// Excludes deleted listings from the count.
    func stageCounts() -> [ListingStage: Int] {
        var counts: [ListingStage: Int] = [:]
        counts.reserveCapacity(ListingStage.allCases.count)

        for listing in self where listing.status != .deleted {
            counts[listing.stage, default: 0] += 1
        }
        return counts
    }
}
