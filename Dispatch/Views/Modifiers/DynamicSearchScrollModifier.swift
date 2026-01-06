//
//  DynamicSearchScrollModifier.swift
//  Dispatch
//
//  Scroll detection modifier for dynamic search box functionality.
//  Created by Claude on 2025-12-23.
//

import SwiftUI

/// A view modifier that detects scroll position and updates the dynamic search state.
///
/// **Requirements:**
/// - iOS 18.0+ (uses `onScrollGeometryChange`)
/// - iPhone only (never triggers on iPad)
/// - `DynamicSearchState` must be in the environment
///
/// **Detection Logic:**
/// - Tracks scroll offset relative to content insets
/// - Updates DynamicSearchState with smooth transitions
/// - Includes debouncing to prevent excessive updates
@available(iOS 18.0, *)
struct DynamicSearchScrollModifier: ViewModifier {
    @EnvironmentObject private var dynamicSearchState: DynamicSearchState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var lastUpdateTime: Date = Date()
    
    // Debouncing threshold to prevent excessive updates
    private let updateThreshold: TimeInterval = 0.016 // ~60fps
    
    func body(content: Content) -> some View {
        #if os(iOS)
        // iPhone only - never trigger on iPad
        if UIDevice.current.userInterfaceIdiom == .phone {
            content
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    // Calculate scroll offset relative to content insets
                    // Positive values indicate scrolling down from the top
                    max(0, geometry.contentInsets.top - geometry.contentOffset.y)
                } action: { _, scrollOffset in
                    handleScrollOffset(scrollOffset)
                }
        } else {
            content
        }
        #else
        content
        #endif
    }
    
    #if os(iOS)
    private func handleScrollOffset(_ scrollOffset: CGFloat) {
        // Debounce updates to prevent excessive state changes
        let now = Date()
        guard now.timeIntervalSince(lastUpdateTime) >= updateThreshold else { return }
        lastUpdateTime = now
        
        // Update the dynamic search state
        dynamicSearchState.updateScrollOffset(scrollOffset)
    }
    #endif
}

// MARK: - View Extension

extension View {
    /// Adds dynamic search scroll detection to a scroll container.
    ///
    /// When the user scrolls, the dynamic search box state is updated
    /// to reflect the current scroll position.
    ///
    /// **Requirements:**
    /// - iOS 18.0+
    /// - iPhone only (no-op on iPad/macOS)
    /// - `DynamicSearchState` must be in the environment
    @ViewBuilder
    func dynamicSearchScroll() -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            modifier(DynamicSearchScrollModifier())
        } else {
            self
        }
        #else
        self
        #endif
    }
}
