//
//  PullToSearchIndicator.swift
//  Dispatch
//
//  Visual indicator for pull-to-search gesture with progressive animation.
//  Created by Claude on 2025-01-10.
//

import SwiftUI

// MARK: - PullToSearchState

/// State machine for pull-to-search gesture
enum PullToSearchState: Equatable {
  /// No pull gesture active
  case idle
  /// Actively pulling, progress 0...1
  case pulling(progress: CGFloat)
  /// Threshold reached, ready to trigger on release
  case armed
}

// MARK: - PullToSearchIndicator

/// Visual indicator showing pull-to-search progress.
///
/// Displays a magnifying glass icon that:
/// - Fades in and scales up as user pulls down
/// - Shows blue capsule background when armed (threshold reached)
/// - Uses progress for opacity/scale only (position is owned by modifier)
struct PullToSearchIndicator: View {

  // MARK: Internal

  let state: PullToSearchState
  let progress: CGFloat

  var body: some View {
    #if os(iOS)
    // Icon with optional armed background - sizes to content, no infinite frames
    Image(systemName: "magnifyingglass")
      .font(.system(size: DS.Spacing.searchPullIndicatorSize, weight: .semibold))
      .foregroundStyle(isArmed ? .white : DS.Colors.Text.secondary)
      .padding(.horizontal, isArmed ? DS.Spacing.searchPullArmedPadding : 0)
      .padding(.vertical, isArmed ? DS.Spacing.searchPullArmedPadding / 2 : 0)
      .background {
        if isArmed {
          Capsule()
            .fill(DS.Colors.searchArmed)
        }
      }
      .scaleEffect(iconScale)
      .opacity(iconOpacity)
      .accessibilityLabel(accessibilityText)
      .accessibilityAddTraits(.isImage)
    #else
    EmptyView()
    #endif
  }

  // MARK: Private

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Whether the indicator is in armed state
  private var isArmed: Bool {
    state == .armed
  }

  /// Progress value (0-1), clamped for safety
  private var clampedProgress: CGFloat {
    min(max(progress, 0), 1)
  }

  /// Icon opacity: 0 when idle, scales with progress
  private var iconOpacity: CGFloat {
    if reduceMotion {
      return state == .idle ? 0 : 1
    }

    switch state {
    case .idle:
      return 0
    case .pulling:
      return clampedProgress
    case .armed:
      return 1
    }
  }

  /// Icon scale: starts at 0.6, grows to 1.0 at full progress
  private var iconScale: CGFloat {
    if reduceMotion {
      return state == .idle ? 0.6 : 1.0
    }
    return 0.6 + (0.4 * clampedProgress)
  }

  /// Accessibility label based on state
  private var accessibilityText: String {
    switch state {
    case .idle:
      "Pull down to search"
    case .pulling:
      "Pull down to search"
    case .armed:
      "Release to search"
    }
  }
}

// MARK: - Preview

#if DEBUG
#Preview("Idle") {
  VStack {
    PullToSearchIndicator(state: .idle, progress: 0)
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(DS.Colors.Background.primary)
}

#Preview("Pulling 50%") {
  VStack {
    PullToSearchIndicator(state: .pulling(progress: 0.5), progress: 0.5)
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(DS.Colors.Background.primary)
}

#Preview("Armed") {
  VStack {
    PullToSearchIndicator(state: .armed, progress: 1)
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(DS.Colors.Background.primary)
}
#endif
