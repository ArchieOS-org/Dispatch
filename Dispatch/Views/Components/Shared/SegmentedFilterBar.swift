//
//  SegmentedFilterBar.swift
//  Dispatch
//
//  Generic segmented picker for filter selection
//  Created by Claude on 2025-12-06.
//

import SwiftUI

/// A generic segmented control that adapts to platform conventions.
/// - iOS/iPadOS: Uses standard Picker with .segmented style.
/// - macOS: Uses custom "Things 3" style pill buttons.
struct SegmentedFilterBar<Filter: Hashable & CaseIterable & Identifiable>: View
where Filter.AllCases: RandomAccessCollection {
    @Binding var selection: Filter
    let displayName: (Filter) -> String
    
    // Namespace for custom macOS animations
    @Namespace private var animationNamespace

    var body: some View {
        #if os(macOS)
        HStack(spacing: 2) {
            ForEach(Filter.allCases) { filter in
                segmentButton(for: filter)
            }
        }
        .padding(2)
        #else
        Picker("Filter", selection: $selection) {
            ForEach(Filter.allCases) { filter in
                Text(displayName(filter))
                    .tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        #endif
    }

    #if os(macOS)
    @ViewBuilder
    private func segmentButton(for filter: Filter) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                selection = filter
            }
        } label: {
            Text(displayName(filter))
                .font(DS.Typography.bodySecondary)
                .fontWeight(selection == filter ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if selection == filter {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .matchedGeometryEffect(id: "selection", in: animationNamespace)
            }
        }
        .foregroundStyle(selection == filter ? .primary : .secondary)
    }
    #endif
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
                Text("Unified Filter Bar")
                    .font(DS.Typography.title3)
                
                // Using custom display name
                SegmentedFilterBar(selection: $selectedFilter) { filter in
                    filter.displayName(forActivities: true)
                }

                Text("Selected: \(selectedFilter.rawValue)")
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }

    return PreviewWrapper()
}
