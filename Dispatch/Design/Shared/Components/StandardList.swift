//
//  StandardList.swift
//  Dispatch
//
//  Created for Dispatch Architecture Unification
//

import SwiftUI

/// A standardized list component that abstracts away the backing implementation (List vs LazyVStack).
/// Enforces consistent row insets, separators, and empty states.
struct StandardList<Data: RandomAccessCollection, RowContent: View, EmptyContent: View>: View where Data.Element: Identifiable {
    
    let data: Data
    @ViewBuilder let rowContent: (Data.Element) -> RowContent
    @ViewBuilder let emptyContent: () -> EmptyContent
    
    init(
        _ data: Data,
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent,
        @ViewBuilder emptyContent: @escaping () -> EmptyContent = { EmptyView() }
    ) {
        self.data = data
        self.rowContent = rowContent
        self.emptyContent = emptyContent
    }
    
    var body: some View {
        if data.isEmpty {
            emptyState
        } else {
            listContent
        }
    }
    
    @ViewBuilder
    private var emptyState: some View {
        VStack {
            Spacer()
            emptyContent()
                .frame(maxWidth: 300)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var listContent: some View {
        // Strategy: Use Native List where strong (iOS), LazyStack where explicit layout needed (maybe macOS?)
        // For "Jobs Logic", we default to Native List for accessibility/perf, 
        // but configured to remove system styling baggage.
        
        List {
            ForEach(data) { item in
                rowContent(item)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 1)
        // Note: StandardScreen owns margins. List should be edge-to-edge inside StandardScreen's column.
        // Wait, if StandardScreen applies padding, the list content is already padded. 
        // BUT `List` on iOS ignores safe areas/padding differently than ScrollView.
        // If we want the list rows to be edge-to-edge relative to the "page", 
        // StandardScreen handles the "Page Margin".
    }
}
