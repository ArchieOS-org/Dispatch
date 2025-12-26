//
//  MacOSSegmentedFilterBar.swift
//  Dispatch
//
//  Created for macOS "Things 3" style filter bar
//

import SwiftUI

/// A custom segmented control for macOS that mimics the "Things 3" aesthetic.
/// Displays options as text, with a pill-shaped background for the selected item.
struct MacOSSegmentedFilterBar<Filter: Hashable & CaseIterable & Identifiable>: View
where Filter.AllCases: RandomAccessCollection {
    @Binding var selection: Filter
    let displayName: (Filter) -> String

    // Namespace for matched geometry effect (optional, but smooths transition)
    @Namespace private var animationNamespace

    var body: some View {
        HStack(spacing: 2) { // Tight spacing for the pill effect
            ForEach(Filter.allCases) { filter in
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        selection = filter
                    }
                } label: {
                    Text(displayName(filter))
                        .font(DS.Typography.subheadline) // Or caption, depending on desired size
                        .fontWeight(selection == filter ? .semibold : .regular)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle()) // ensure frame is tappable
                }
                .buttonStyle(.plain)
                .background {
                    if selection == filter {
                        Capsule()
                            .fill(Color.secondary.opacity(0.2)) // Subtle grey background
                            .matchedGeometryEffect(id: "selection", in: animationNamespace)
                    }
                }
                .foregroundStyle(selection == filter ? .primary : .secondary)
            }
        }
        .padding(2)
        // Optional container background if we wanted the whole bar to have a backing, 
        // but Things 3 typically just has the pills floating or in a minimal group.
    }
}

// MARK: - Convenience Initializer for RawRepresentable

extension MacOSSegmentedFilterBar where Filter: RawRepresentable, Filter.RawValue == String {
    /// Convenience initializer that uses rawValue as display name
    init(selection: Binding<Filter>) {
        self._selection = selection
        self.displayName = { $0.rawValue }
    }
}

// MARK: - Preview

#Preview("MacOS Segmented Filter Bar") {
    struct PreviewWrapper: View {
        @State private var selectedFilter: ClaimFilter = .mine

        var body: some View {
            VStack {
                MacOSSegmentedFilterBar(selection: $selectedFilter) { filter in
                     filter.displayName(forActivities: false)
                }
                .padding()
                
                Spacer()
            }
            .frame(width: 400, height: 200)
        }
    }
    return PreviewWrapper()
}
