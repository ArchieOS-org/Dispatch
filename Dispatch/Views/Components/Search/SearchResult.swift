//
//  SearchResult.swift
//  Dispatch
//
//  Unified search result type wrapping TaskItem, Activity, or Listing
//  Created by Claude on 2025-12-18.
//

import SwiftUI

/// A unified wrapper for search results across Tasks, Activities, and Listings.
///
/// Provides a common interface for:
/// - Display properties (title, subtitle, icon, color)
/// - Navigation (converting to appropriate navigation values)
/// - Ranking (prefix matching, title vs subtitle)
///
/// **Result Sections:**
/// - Tasks: Title = task title, Subtitle = description or "No description"
/// - Activities: Title = activity title, Subtitle = type label
/// - Listings: Title = address, Subtitle = city + status
enum SearchResult: Identifiable, Hashable {
    case task(TaskItem)
    case activity(Activity)
    case listing(Listing)
    case navigation(title: String, icon: String, tab: AppTab, badgeCount: Int? = nil)

    // MARK: - Identifiable

    var id: UUID {
        switch self {
        case .task(let task): return task.id
        case .activity(let activity): return activity.id
        case .listing(let listing): return listing.id
        case .navigation(let title, _, _, _):
            // Stable UUID based on title for navigation items
            // We implementation a simple stable hash to hex string conversion to ensure persistence stability
            let stableHash = title.utf8.reduce(5381) { ($0 << 5) &+ $0 &+ Int($1) }
            let hexSuffix = String(format: "%012x", stableHash & 0xFFFFFFFFFFFF)
            return UUID(uuidString: "DEADBEEF-0000-0000-0000-\(hexSuffix)") ?? UUID()
        }
    }

    // MARK: - Display Properties

    /// Primary display text
    var title: String {
        switch self {
        case .task(let task): return task.title
        case .activity(let activity): return activity.title
        case .listing(let listing): return listing.address
        case .navigation(let title, _, _, _): return title
        }
    }

    /// Secondary display text
    var subtitle: String {
        switch self {
        case .task(let task):
            return task.taskDescription.isEmpty ? "No description" : task.taskDescription
        case .activity(let activity):
            return activity.type.displayName
        case .listing(let listing):
            let status = listing.status.rawValue.capitalized
            return listing.city.isEmpty ? status : "\(listing.city) · \(status)"
        case .navigation: return "Quick Jump"
        }
    }

    /// Icon name (SF Symbol)
    var icon: String {
        switch self {
        case .task: return DS.Icons.Entity.task
        case .activity(let activity):
            switch activity.type {
            case .call: return DS.Icons.ActivityType.call
            case .email: return DS.Icons.ActivityType.email
            case .meeting: return DS.Icons.ActivityType.meeting
            case .showProperty: return DS.Icons.ActivityType.showProperty
            case .followUp: return DS.Icons.ActivityType.followUp
            case .other: return DS.Icons.ActivityType.other
            }
        case .listing: return DS.Icons.Entity.listing
        case .navigation(_, let icon, _, _): return icon
        }
    }

    /// Accent color for the result type
    var accentColor: Color {
        switch self {
        case .task: return DS.Colors.Section.tasks
        case .activity: return DS.Colors.Section.activities
        case .listing: return DS.Colors.Section.listings
        case .navigation: return .blue // Standard navigation color
        }
    }

    /// Section header title
    var sectionTitle: String {
        switch self {
        case .task: return "Tasks"
        case .activity: return "Activities"
        case .listing: return "Listings"
        case .navigation: return "Navigation"
        }
    }

    // MARK: - Status

    /// Whether the item is completed (tasks/activities only)
    var isCompleted: Bool {
        switch self {
        case .task(let task): return task.status == .completed
        case .activity(let activity): return activity.status == .completed
        case .listing: return false
        case .navigation: return false
        }
    }

    /// Whether the item is deleted
    var isDeleted: Bool {
        switch self {
        case .task(let task): return task.status == .deleted
        case .activity(let activity): return activity.status == .deleted
        case .listing(let listing): return listing.status == .deleted
        case .navigation: return false
        }
    }

    // MARK: - Sorting & Ranking

    /// Sort priority for section ordering (Tasks first, then Activities, then Listings)
    var sectionOrder: Int {
        switch self {
        case .navigation: return -1 // Navigation always first
        case .task: return 0
        case .activity: return 1
        case .listing: return 2
        }
    }
    
    // MARK: - Navigation Badges
    
    var badgeCount: Int? {
        switch self {
        case .navigation(_, _, _, let count): return count
        default: return nil
        }
    }
}

// MARK: - Filtering & Ranking

extension SearchResult {
    /// Checks if this result matches the given query (case-insensitive)
    func matches(query: String) -> Bool {
        let lowercasedQuery = query.lowercased()
        return title.lowercased().contains(lowercasedQuery) ||
               subtitle.lowercased().contains(lowercasedQuery)
    }

    /// Calculates a ranking score for sorting results.
    /// Higher score = better match.
    ///
    /// Ranking priorities:
    /// 1. Prefix match on title (highest)
    /// 2. Contains match on title
    /// 3. Prefix match on subtitle
    /// 4. Contains match on subtitle (lowest)
    /// 5. Open items beat completed items
    func rankingScore(for query: String) -> Int {
        let lowercasedQuery = query.lowercased()
        let lowercasedTitle = title.lowercased()
        let lowercasedSubtitle = subtitle.lowercased()

        var score = 0

        // Prefix match on title is highest priority
        if lowercasedTitle.hasPrefix(lowercasedQuery) {
            score += 1000
        } else if lowercasedTitle.contains(lowercasedQuery) {
            score += 500
        }

        // Subtitle matches are lower priority
        if lowercasedSubtitle.hasPrefix(lowercasedQuery) {
            score += 100
        } else if lowercasedSubtitle.contains(lowercasedQuery) {
            score += 50
        }

        // Open items rank higher than completed
        if !isCompleted {
            score += 10
        }

        return score
    }
}

// MARK: - Activity Type Display Name

private extension ActivityType {
    var displayName: String {
        switch self {
        case .call: return "Call"
        case .email: return "Email"
        case .meeting: return "Meeting"
        case .showProperty: return "Showing"
        case .followUp: return "Follow-up"
        case .other: return "Activity"
        }
    }
}

// MARK: - Search Result Collection Helpers

extension Array where Element == SearchResult {
    /// Filters results matching the query and sorts by ranking score
    func filtered(by query: String) -> [SearchResult] {
        guard !query.isEmpty else { return [] }

        return self
            .filter { !$0.isDeleted && $0.matches(query: query) }
            .sorted { $0.rankingScore(for: query) > $1.rankingScore(for: query) }
    }

    /// Groups results by section with per-section limit
    func groupedBySectionWithLimit(_ limit: Int = 20) -> [(section: String, results: [SearchResult])] {
        let grouped = Dictionary(grouping: self) { $0.sectionTitle }

        return grouped
            .map { (section: $0.key, results: Array($0.value.prefix(limit))) }
            .sorted { lhs, rhs in
                // Sort sections: Tasks, Activities, Listings
                let lhsOrder = lhs.results.first?.sectionOrder ?? 0
                let rhsOrder = rhs.results.first?.sectionOrder ?? 0
                return lhsOrder < rhsOrder
            }
    }
}
