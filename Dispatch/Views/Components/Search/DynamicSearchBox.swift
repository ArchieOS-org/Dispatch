//
//  DynamicSearchBox.swift
//  Dispatch
//
//  A dynamic search box that changes appearance based on scroll position.
//  Created by Claude on 2025-12-23.
//

import SwiftUI

/// A search box component that dynamically changes its appearance based on scroll state.
///
/// Features:
/// - Changes from gray to blue based on scroll position
/// - Shows/hides dropdown arrow
/// - Smooth position and color transitions
/// - Integrates with SearchPresentationManager for search functionality
struct DynamicSearchBox: View {
    @EnvironmentObject private var dynamicSearchState: DynamicSearchState
    @EnvironmentObject private var searchManager: SearchPresentationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: DS.Spacing.dynamicSearchArrowSpacing) {
            // Search Box
            searchBox
            
            // Dropdown Arrow
            if dynamicSearchState.showArrow {
                dropdownArrow
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .offset(y: dynamicSearchState.searchBoxOffset)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.3),
            value: dynamicSearchState.searchBoxOffset
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.3),
            value: dynamicSearchState.showArrow
        )
    }
    
    // MARK: - Search Box
    
    private var searchBox: some View {
        Button {
            // Present search overlay when tapped
            if reduceMotion {
                searchManager.presentSearch()
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    searchManager.presentSearch()
                }
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                // Search icon
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(searchIconColor)
                
                // Search text
                Text("Quick Find")
                    .font(DS.Typography.body)
                    .foregroundColor(searchTextColor)
                
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.dynamicSearchBoxPadding)
            .frame(height: DS.Spacing.dynamicSearchBoxHeight)
            .background(searchBoxBackground)
            .cornerRadius(DS.Spacing.dynamicSearchBoxRadius)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open search")
        .accessibilityHint("Tap to search tasks, activities, and listings")
    }
    
    // MARK: - Dropdown Arrow
    
    private var dropdownArrow: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: DS.Spacing.dynamicSearchArrowSize, weight: .medium))
            .foregroundColor(arrowColor)
            .accessibilityHidden(true)
    }
    
    // MARK: - Dynamic Colors
    
    private var searchBoxBackground: Color {
        dynamicSearchState.useBlueStyle
            ? DS.Colors.DynamicSearch.activatedBackground
            : DS.Colors.DynamicSearch.defaultBackground
    }
    
    private var searchIconColor: Color {
        dynamicSearchState.useBlueStyle
            ? DS.Colors.DynamicSearch.activatedText
            : DS.Colors.DynamicSearch.defaultText
    }
    
    private var searchTextColor: Color {
        dynamicSearchState.useBlueStyle
            ? DS.Colors.DynamicSearch.activatedText
            : DS.Colors.DynamicSearch.defaultText
    }
    
    private var arrowColor: Color {
        dynamicSearchState.useBlueStyle
            ? DS.Colors.DynamicSearch.activatedArrow
            : DS.Colors.DynamicSearch.defaultArrow
    }
}

// MARK: - Preview

#Preview("Dynamic Search Box - Default") {
    VStack(spacing: 40) {
        DynamicSearchBox()
            .environmentObject({
                let state = DynamicSearchState()
                return state
            }())
            .environmentObject(SearchPresentationManager())
        
        Text("Default State")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
    .background(DS.Colors.Background.grouped)
}

#Preview("Dynamic Search Box - Pulled") {
    VStack(spacing: 40) {
        DynamicSearchBox()
            .environmentObject({
                let state = DynamicSearchState()
                state.updateScrollOffset(40) // Pulled state
                return state
            }())
            .environmentObject(SearchPresentationManager())
        
        Text("Pulled State")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
    .background(DS.Colors.Background.grouped)
}

#Preview("Dynamic Search Box - Activated") {
    VStack(spacing: 40) {
        DynamicSearchBox()
            .environmentObject({
                let state = DynamicSearchState()
                state.updateScrollOffset(80) // Activated state
                return state
            }())
            .environmentObject(SearchPresentationManager())
        
        Text("Activated State")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
    .background(DS.Colors.Background.grouped)
}
