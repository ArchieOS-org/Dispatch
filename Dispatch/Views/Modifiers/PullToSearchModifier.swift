//
//  PullToSearchModifier.swift
//  Dispatch
//
//  iOS 18+ scroll-based pull-to-search modifier using native scroll APIs.
//  Created by Claude on 2025-12-18.
//

import SwiftUI

/// A view modifier that triggers search overlay when the user pulls down
/// past a threshold while at the top of a scroll view.
///
/// **Requirements:**
/// - iOS 18.0+ (uses `onScrollGeometryChange` and `onScrollPhaseChange`)
/// - iPhone only (never triggers on iPad)
///
/// **Detection Logic:**
/// - Pull distance = `max(0, contentInsets.top - contentOffset.y)`
/// - At rest: `contentOffset.y == contentInsets.top` → pullDistance = 0
/// - Pulling down: `contentOffset.y < contentInsets.top` → pullDistance > 0
/// - Triggers once per pull gesture via `didTriggerThisPull` flag
/// - Resets when `pullDistance < 2` OR scroll phase becomes `.idle`
@available(iOS 18.0, *)
struct PullToSearchModifier: ViewModifier {
    @EnvironmentObject private var searchManager: SearchPresentationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var didTriggerThisPull = false
    @State private var currentPullDistance: CGFloat = 0

    func body(content: Content) -> some View {
        #if os(iOS)
        // iPhone only - never trigger on iPad
        if UIDevice.current.userInterfaceIdiom == .phone {
            content
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    // Correct overscroll math: relative to contentInsets.top
                    // When at rest, contentOffset.y == contentInsets.top
                    // Pulling down makes contentOffset.y < contentInsets.top
                    max(0, geometry.contentInsets.top - geometry.contentOffset.y)
                } action: { _, pullDistance in
                    currentPullDistance = pullDistance
                    handlePullDistance(pullDistance)
                }
                .onScrollPhaseChange { _, newPhase, _ in
                    // Reset when scroll returns to idle
                    if newPhase == .idle {
                        didTriggerThisPull = false
                    }
                }
        } else {
            content
        }
        #else
        content
        #endif
    }

    #if os(iOS)
    private func handlePullDistance(_ pullDistance: CGFloat) {
        // Reset if pulled back near resting position
        if pullDistance < 2 {
            didTriggerThisPull = false
        }

        // Trigger once per pull when threshold exceeded
        guard pullDistance >= DS.Spacing.searchPullThreshold,
              !didTriggerThisPull,
              !searchManager.isSearchPresented else { return }

        didTriggerThisPull = true
        HapticFeedback.light()

        if reduceMotion {
            searchManager.presentSearch()
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                searchManager.presentSearch()
            }
        }
    }
    #endif
}

// MARK: - View Extension

extension View {
    /// Adds pull-to-search functionality to a scroll container.
    ///
    /// When the user pulls down past the threshold while at the top of the scroll view,
    /// the search overlay is presented.
    ///
    /// **Requirements:**
    /// - iOS 18.0+
    /// - iPhone only (no-op on iPad/macOS)
    /// - `SearchPresentationManager` must be in the environment
    @ViewBuilder
    func pullToSearch() -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            modifier(PullToSearchModifier())
        } else {
            self
        }
        #else
        self
        #endif
    }
}
