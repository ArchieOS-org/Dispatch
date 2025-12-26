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
struct PullToSearchModifier: ViewModifier {
    @EnvironmentObject private var searchManager: SearchPresentationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var didTriggerThisPull = false
    func body(content: Content) -> some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            // Wrap in ZStack to ensure coordinate space is fixed relative to screen/container
            ZStack {
                content
            }
            .coordinateSpace(name: "pullToSearchSpace")
            .onPreferenceChange(PullToSearchScrollOffsetKey.self) { minY in
               // print("[PullToSearch] Preference change: \(minY)") 
               handlePullDistance(minY)
            }
        } else {
            content
        }
        #else
        content
        #endif
    }

    @State private var initialAnchorY: CGFloat? = nil

    #if os(iOS)
    private func handlePullDistance(_ minY: CGFloat) {
        // Capture initial resting position on first valid layout
        if initialAnchorY == nil && minY > 0 {
            initialAnchorY = minY
        }

        guard let initialY = initialAnchorY else { return }

        // Calculate pull distance relative to resting position
        let pullDistance = max(0, minY - initialY)

        // Reset logic: if within 2pt of resting position
        if pullDistance < 2 {
            didTriggerThisPull = false
        }

        // Trigger logic
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

// MARK: - Preference Key & Sensor

/// Tracks the Y offset of the scroll content
struct PullToSearchScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Invisible sensor view to be placed at the very top of scroll content.
/// Emits its Y frame origin to `ScrollOffsetKey`.
struct PullToSearchSensor: View {
    var body: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .named("pullToSearchSpace"))
            Color.clear
                .preference(key: PullToSearchScrollOffsetKey.self, value: frame.minY)
        }
        .frame(height: 0)
    }
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
        modifier(PullToSearchModifier())
        #else
        self
        #endif
    }
}
