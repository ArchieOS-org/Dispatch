//
//  PullToSearchModifier.swift
//  Dispatch
//
//  iOS 18+ scroll-based pull-to-search modifier using native scroll APIs.
//  Supports both iPhone and iPad with visual feedback and release-to-trigger.
//  Created by Claude on 2025-12-18.
//

import SwiftUI

// MARK: - PullToSearchStateKey

/// PreferenceKey for passing pull-to-search state up the view hierarchy.
/// Used by PullToSearchHost to render the indicator at screen level.
struct PullToSearchStateKey: PreferenceKey {
  struct Value: Equatable {
    var state: PullToSearchState = .idle
    var progress: CGFloat = 0
    var pullDistance: CGFloat = 0
  }

  static var defaultValue = Value()

  static func reduce(value: inout Value, nextValue: () -> Value) {
    value = nextValue()
  }
}

// MARK: - PullToSearchLayout

/// Shared layout calculations for pull-to-search indicator positioning.
/// Single source of truth - used by both tracking modifier and host.
enum PullToSearchLayout {
  /// Computes the 1:1 icon offset for the pull indicator (direct overlay rendering).
  ///
  /// The indicator moves down exactly 1:1 with the pull distance.
  /// At rest (pullDistance=0): hidden above the content area
  /// At threshold: docked at endOffset position
  static func iconOffset(pullDistance: CGFloat) -> CGFloat {
    let threshold = DS.Spacing.searchPullThreshold
    let endOffset = DS.Spacing.sm
    let startOffset = endOffset - threshold
    return min(endOffset, startOffset + pullDistance)
  }
}

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

  #if os(iOS)
  private struct PullToSearchMetrics: Equatable {
    let pullDistance: CGFloat
    let contentTopInset: CGFloat
  }
  #endif

  func body(content: Content) -> some View {
    #if os(iOS)
    content
      .onScrollGeometryChange(for: PullToSearchMetrics.self) { geometry in
        // The "at rest" position is contentOffset.y == -contentInsets.top
        // We're only overscrolling when contentOffset.y < -contentInsets.top
        let topInset = geometry.contentInsets.top
        let topEdgeY = -topInset
        guard geometry.contentOffset.y < topEdgeY else {
          return PullToSearchMetrics(pullDistance: 0, contentTopInset: topInset)
        }
        let pullDistance = topEdgeY - geometry.contentOffset.y // positive pull distance
        return PullToSearchMetrics(pullDistance: pullDistance, contentTopInset: topInset)
      } action: { _, metrics in
        currentPullDistance = metrics.pullDistance
        currentContentTopInset = metrics.contentTopInset
        updatePullState(pullDistance: metrics.pullDistance)
      }
      .onScrollPhaseChange { oldPhase, newPhase in
        handlePhaseChange(from: oldPhase, to: newPhase)
      }
      .overlay(alignment: .top) {
        GeometryReader { proxy in
          // contentInsets.top includes safe-area + navigation bar/large-title inset.
          // Shift the indicator up by the nav-bar portion so it docks above titles.
          let safeTop = proxy.safeAreaInsets.top
          let navBarInset = max(0, currentContentTopInset - safeTop)

          PullToSearchIndicator(state: state, progress: progress)
            .offset(y: -navBarInset + computeIconOffset(pullDistance: currentPullDistance))
            .frame(maxWidth: .infinity, alignment: .top)
            .allowsHitTesting(false)
            .zIndex(999)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .allowsHitTesting(false)
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

  /// Current pull distance for 1:1 indicator offset + release checks
  @State private var currentPullDistance: CGFloat = 0

  /// Latest scroll content top inset (safe area + nav bar/large title)
  @State private var currentContentTopInset: CGFloat = 0

  /// Prevents multiple triggers per pull
  @State private var didTriggerThisPull = false

  /// Prevents multiple haptics per armed entry
  @State private var didFireHaptic = false

  #if os(iOS)
  /// Pull progress (0-1)
  private var progress: CGFloat {
    let threshold = DS.Spacing.searchPullThreshold
    guard threshold > 0 else { return 0 }
    return min(1.0, max(0.0, currentPullDistance / threshold))
  }

  /// Computes the 1:1 icon offset for the pull indicator.
  ///
  /// The indicator moves down exactly 1:1 with the pull distance.
  /// At rest (pullDistance=0): hidden above the content area
  /// At threshold: docked at endOffset position
  private func computeIconOffset(pullDistance: CGFloat) -> CGFloat {
    let threshold = DS.Spacing.searchPullThreshold
    // Dock position relative to scroll view's top (small margin)
    let endOffset = DS.Spacing.sm
    // Start position ensures we dock exactly at threshold
    let startOffset = endOffset - threshold
    // True 1:1 tracking, capped at endOffset
    return min(endOffset, startOffset + pullDistance)
  }

  /// Updates the pull state based on current pull distance
  private func updatePullState(pullDistance: CGFloat) {
    let threshold = DS.Spacing.searchPullThreshold
    let progress = min(1.0, max(0.0, pullDistance / threshold))

    switch state {
    case .armed:
      if progress <= 0 {
        state = .idle
        didFireHaptic = false
      } else if progress < 0.85 {
        state = .pulling(progress: progress)
        didFireHaptic = false
      }

    case .pulling, .idle:
      if progress >= 1.0 {
        state = .armed
        if !didFireHaptic {
          HapticFeedback.medium()
          didFireHaptic = true
        }
      } else if progress > 0 {
        state = .pulling(progress: progress)
      } else {
        state = .idle
        didFireHaptic = false
      }
    }

    if pullDistance <= 1 {
      didTriggerThisPull = false
    }
  }

  /// Handles scroll phase changes to detect release
  private func handlePhaseChange(from oldPhase: ScrollPhase, to newPhase: ScrollPhase) {
    // Detect finger lift: transitioning FROM interacting/tracking TO released state
    // IMPORTANT: Finger lift typically goes .interacting → .decelerating (not .idle)
    let wasInteracting = (oldPhase == .interacting || oldPhase == .tracking)
    let isReleased = (newPhase == .decelerating || newPhase == .idle || newPhase == .animating)

    let threshold = DS.Spacing.searchPullThreshold
    if
      wasInteracting, isReleased,
      state == .armed,
      currentPullDistance >= threshold,
      !didTriggerThisPull
    {
      didTriggerThisPull = true
      triggerSearch()
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

// MARK: - PullToSearchTrackingModifier

/// Tracking-only modifier that publishes pull-to-search state via PreferenceKey.
/// Does NOT render the indicator - that's handled by PullToSearchHost.
/// Used when indicator rendering should happen at a higher level in the view hierarchy.
struct PullToSearchTrackingModifier: ViewModifier {

  // MARK: Internal

  func body(content: Content) -> some View {
    #if os(iOS)
    content
      .onScrollGeometryChange(for: CGFloat.self) { geometry in
        let topInset = geometry.contentInsets.top
        let topEdgeY = -topInset
        guard geometry.contentOffset.y < topEdgeY else { return 0 }
        return topEdgeY - geometry.contentOffset.y
      } action: { _, pullDistance in
        currentPullDistance = pullDistance
        updatePullState(pullDistance: pullDistance)
      }
      .onScrollPhaseChange { oldPhase, newPhase in
        handlePhaseChange(from: oldPhase, to: newPhase)
      }
      .preference(
        key: PullToSearchStateKey.self,
        value: (currentPullDistance > 0 || state != .idle)
          ? .init(state: state, progress: progress, pullDistance: currentPullDistance)
          : .init()
      )
    #else
    content
    #endif
  }

  // MARK: Private

  @EnvironmentObject private var appState: AppState
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var state: PullToSearchState = .idle
  @State private var currentPullDistance: CGFloat = 0
  @State private var didTriggerThisPull = false
  @State private var didFireHaptic = false

  #if os(iOS)
  private var progress: CGFloat {
    let threshold = DS.Spacing.searchPullThreshold
    guard threshold > 0 else { return 0 }
    return min(1.0, max(0.0, currentPullDistance / threshold))
  }

  private func updatePullState(pullDistance: CGFloat) {
    let threshold = DS.Spacing.searchPullThreshold
    let progress = min(1.0, max(0.0, pullDistance / threshold))

    switch state {
    case .armed:
      if progress <= 0 {
        state = .idle
        didFireHaptic = false
      } else if progress < 0.85 {
        state = .pulling(progress: progress)
        didFireHaptic = false
      }

    case .pulling, .idle:
      if progress >= 1.0 {
        state = .armed
        if !didFireHaptic {
          HapticFeedback.medium()
          didFireHaptic = true
        }
      } else if progress > 0 {
        state = .pulling(progress: progress)
      } else {
        state = .idle
        didFireHaptic = false
      }
    }

    if pullDistance <= 1 {
      didTriggerThisPull = false
    }
  }

  private func handlePhaseChange(from oldPhase: ScrollPhase, to newPhase: ScrollPhase) {
    let wasInteracting = (oldPhase == .interacting || oldPhase == .tracking)
    let isReleased = (newPhase == .decelerating || newPhase == .idle || newPhase == .animating)

    let threshold = DS.Spacing.searchPullThreshold
    if
      wasInteracting, isReleased,
      state == .armed,
      currentPullDistance >= threshold,
      !didTriggerThisPull
    {
      didTriggerThisPull = true
      triggerSearch()
    }
  }

  private func triggerSearch() {
    guard appState.overlayState == .none else { return }

    if reduceMotion {
      appState.dispatch(.openSearch(initialText: nil))
    } else {
      withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
        appState.dispatch(.openSearch(initialText: nil))
      }
    }

    state = .idle
    didFireHaptic = false
  }
  #endif
}

// MARK: - PullToSearchScrollOffsetKey

/// Tracks the Y offset of the scroll content
/// Note: This preference key approach is superseded by iOS 18 scroll APIs
/// but kept for backward compatibility with existing PullToSearchSensor usage.
struct PullToSearchScrollOffsetKey: PreferenceKey {
  static var defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

// MARK: - PullToSearchSensor

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

// MARK: - PullToSearchDisabledKey

/// Environment key to disable pull-to-search in a view hierarchy.
/// Used by Settings screens to opt out of pull-to-search.
private struct PullToSearchDisabledKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  /// When true, pull-to-search is disabled for this view hierarchy.
  /// Set this at a root container (like Settings) to disable for all descendants.
  var pullToSearchDisabled: Bool {
    get { self[PullToSearchDisabledKey.self] }
    set { self[PullToSearchDisabledKey.self] = newValue }
  }
}

// MARK: - PullToSearchConditionalModifier

/// Conditionally applies pull-to-search based on enabled flag.
/// Used by StandardScreen and StandardList to centralize pull-to-search application.
struct PullToSearchConditionalModifier: ViewModifier {
  let enabled: Bool

  func body(content: Content) -> some View {
    if enabled {
      content.pullToSearch()
    } else {
      content
    }
  }
}

// MARK: - PullToSearchTrackingConditionalModifier

/// Conditionally applies pull-to-search tracking (no rendering) based on enabled flag.
/// Used when indicator rendering is handled by PullToSearchHost at a higher level.
struct PullToSearchTrackingConditionalModifier: ViewModifier {
  let enabled: Bool

  func body(content: Content) -> some View {
    if enabled {
      content.pullToSearchTracking()
    } else {
      content
    }
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

  /// Adds pull-to-search tracking without rendering the indicator.
  ///
  /// Use this when the indicator should be rendered at a higher level
  /// via PullToSearchHost (e.g., to escape navigation bar coordinate space).
  ///
  /// **Requirements:**
  /// - iOS 18.0+
  /// - Must be paired with PullToSearchHost ancestor
  @ViewBuilder
  func pullToSearchTracking() -> some View {
    #if os(iOS)
    modifier(PullToSearchTrackingModifier())
    #else
    self
    #endif
  }
}
