//
//  PullToSearchModifier.swift
//  Dispatch
//
//  iOS 18+ scroll-based pull-to-search modifier using native scroll APIs.
//  Supports both iPhone and iPad with visual feedback and release-to-trigger.
//  Created by Claude on 2025-12-18.
//

import SwiftUI

// MARK: - PullToSearchModifier

/// A view modifier that triggers search overlay when the user pulls down
/// past a threshold and releases while at the top of a scroll view.
///
/// **Requirements:**
/// - iOS 18.0+ (uses `onScrollGeometryChange` and `onScrollPhaseChange`)
/// - Works on both iPhone and iPad
///
/// **Behavior:**
/// - Shows magnifying glass icon that animates down as user pulls
/// - Blue background appears when armed (threshold reached)
/// - Haptic fires when entering armed state
/// - Search triggers on release, not at threshold
/// - Respects `accessibilityReduceMotion`
struct PullToSearchModifier: ViewModifier {

  // MARK: Internal

  func body(content: Content) -> some View {
    #if os(iOS)
    content
      .onScrollGeometryChange(for: CGFloat.self) { geometry in
        // Calculate pull distance from content offset
        // When pulling down at top, contentOffset.y becomes negative
        max(0, geometry.contentInsets.top - geometry.contentOffset.y)
      } action: { _, pullDistance in
        updatePullState(pullDistance: pullDistance)
      }
      .onScrollPhaseChange { oldPhase, newPhase in
        handlePhaseChange(from: oldPhase, to: newPhase)
      }
      .overlay(alignment: .top) {
        // Visual indicator overlay (positioned at top)
        PullToSearchIndicator(state: state)
      }
    #else
    content // macOS: no-op
    #endif
  }

  // MARK: Private

  @EnvironmentObject private var appState: AppState // One Boss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Current pull-to-search state
  @State private var state: PullToSearchState = .idle

  /// Prevents multiple haptics per armed entry
  @State private var didFireHaptic = false

  #if os(iOS)
  /// Updates the pull state based on current pull distance
  private func updatePullState(pullDistance: CGFloat) {
    let threshold = DS.Spacing.searchPullThreshold
    let progress = min(1.0, pullDistance / threshold)

    if progress >= 1.0 {
      // Enter armed state
      if state != .armed {
        state = .armed
        if !didFireHaptic {
          HapticFeedback.medium() // Stronger haptic for "armed"
          didFireHaptic = true
        }
      }
    } else if progress > 0.05 {
      // Pulling but not armed (small threshold to avoid jitter)
      state = .pulling(progress: progress)
      // Reset haptic flag when un-armed
      if didFireHaptic {
        didFireHaptic = false
      }
    } else {
      // Idle
      if state != .idle {
        state = .idle
        didFireHaptic = false
      }
    }
  }

  /// Handles scroll phase changes to detect release
  private func handlePhaseChange(from oldPhase: ScrollPhase, to newPhase: ScrollPhase) {
    // Detect finger lift: transitioning FROM interacting/tracking TO released state
    // IMPORTANT: Finger lift typically goes .interacting → .decelerating (not .idle)
    let wasInteracting = (oldPhase == .interacting || oldPhase == .tracking)
    let isReleased = (newPhase == .decelerating || newPhase == .idle || newPhase == .animating)

    if wasInteracting && isReleased && state == .armed {
      triggerSearch()
    }

    // Reset state when scroll fully settles
    if newPhase == .idle {
      state = .idle
      didFireHaptic = false
    }
  }

  /// Triggers the search overlay via AppState
  private func triggerSearch() {
    // Check if ANY overlay is active (One Boss) to prevent double trigger
    guard appState.overlayState == .none else { return }

    // Dispatch Command (One Boss)
    if reduceMotion {
      appState.dispatch(.openSearch(initialText: nil))
    } else {
      withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
        appState.dispatch(.openSearch(initialText: nil))
      }
    }

    // Reset state after triggering
    state = .idle
    didFireHaptic = false
  }
  #endif
}

// MARK: - PullToSearchScrollOffsetKey (Legacy - kept for backward compatibility)

/// Tracks the Y offset of the scroll content
/// Note: This preference key approach is superseded by iOS 18 scroll APIs
/// but kept for backward compatibility with existing PullToSearchSensor usage.
struct PullToSearchScrollOffsetKey: PreferenceKey {
  static var defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

// MARK: - PullToSearchSensor (Legacy - kept for backward compatibility)

/// Invisible sensor view to be placed at the very top of scroll content.
/// Note: This is superseded by iOS 18 `onScrollGeometryChange` but kept
/// to avoid breaking existing code that uses it.
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
  /// When the user pulls down past the threshold and releases,
  /// the search overlay is presented.
  ///
  /// **Requirements:**
  /// - iOS 18.0+
  /// - Works on iPhone and iPad (no-op on macOS)
  ///
  /// **Behavior:**
  /// - Shows magnifying glass icon during pull
  /// - Blue background when armed (threshold reached)
  /// - Haptic fires when entering armed state
  /// - Search triggers on release
  @ViewBuilder
  func pullToSearch() -> some View {
    #if os(iOS)
    modifier(PullToSearchModifier())
    #else
    self
    #endif
  }
}
