//
//  DateSectionHeader.swift
//  Dispatch
//
//  Styled section header for date-based groupings
//  Created by Claude on 2025-12-06.
//

import SwiftUI

/// A styled section header for date-based work item groupings.
/// Displays the section title with appropriate coloring (red for overdue).
struct DateSectionHeader: View {
    let section: DateSection

    var body: some View {
        Text(section.rawValue)
            .font(DS.Typography.headline)
            .foregroundColor(section.headerColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.Background.secondary)
            .listRowInsets(EdgeInsets())
    }
}

// MARK: - Preview

#Preview("Date Section Headers") {
    List {
        ForEach(DateSection.allCases) { section in
            Section {
                Text("Sample item in \(section.rawValue)")
                    .font(DS.Typography.body)
            } header: {
                DateSectionHeader(section: section)
            }
        }
    }
    .listStyle(.plain)
}
