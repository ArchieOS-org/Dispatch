//
//  SegmentedFilterBar.swift
//  Dispatch
//
//  Generic segmented picker for filter selection
//  Created by Claude on 2025-12-06.
//

import SwiftUI

/// A generic segmented control that works with any CaseIterable enum.
/// Used in TaskListView and ActivityListView for claim filtering.
struct SegmentedFilterBar<Filter: Hashable & CaseIterable & Identifiable>: View
where Filter.AllCases: RandomAccessCollection {
    @Binding var selection: Filter
    let displayName: (Filter) -> String

    var body: some View {
        Picker("Filter", selection: $selection) {
            ForEach(Filter.allCases) { filter in
                Text(displayName(filter))
                    .tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }
}

// MARK: - Convenience Initializer for RawRepresentable

extension SegmentedFilterBar where Filter: RawRepresentable, Filter.RawValue == String {
    /// Convenience initializer that uses rawValue as display name
    init(selection: Binding<Filter>) {
        self._selection = selection
        self.displayName = { $0.rawValue }
    }
}

// MARK: - Preview

#Preview("Segmented Filter Bar") {
    struct PreviewWrapper: View {
        @State private var selectedFilter: ClaimFilter = .mine

        var body: some View {
            VStack(spacing: DS.Spacing.lg) {
                // Using rawValue (default)
                SegmentedFilterBar(selection: $selectedFilter)

                // Using custom display name
                SegmentedFilterBar(selection: $selectedFilter) { filter in
                    filter.displayName(forActivities: true)
                }

                Text("Selected: \(selectedFilter.rawValue)")
                    .font(DS.Typography.body)

                Spacer()
            }
            .padding(.top, DS.Spacing.md)
        }
    }

    return PreviewWrapper()
}
