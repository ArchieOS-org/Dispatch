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
/// - Tracks linearly with finger movement
struct PullToSearchIndicator: View {

  // MARK: Internal

  let state: PullToSearchState

  var body: some View {
    #if os(iOS)
    ZStack {
      // Blue capsule background (only visible when armed)
      if isArmed {
        Capsule()
          .fill(DS.Colors.searchArmed)
          .frame(
            width: DS.Spacing.searchPullIndicatorSize + DS.Spacing.searchPullArmedPadding * 2,
            height: DS.Spacing.searchPullIndicatorSize + DS.Spacing.searchPullArmedPadding
          )
      }

      // Magnifying glass icon
      Image(systemName: "magnifyingglass")
        .font(.system(size: DS.Spacing.searchPullIndicatorSize, weight: .medium))
        .foregroundStyle(isArmed ? .white : DS.Colors.Text.secondary)
    }
    .scaleEffect(iconScale)
    .opacity(iconOpacity)
    .offset(y: iconOffset)
    .accessibilityLabel(accessibilityText)
    .accessibilityAddTraits(.isImage)
    #else
    EmptyView()
    #endif
  }

  // MARK: Private

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Progress value (0-1) derived from state
  private var progress: CGFloat {
    switch state {
    case .idle:
      return 0
    case .pulling(let p):
      return p
    case .armed:
      return 1
    }
  }

  /// Whether the indicator is in armed state
  private var isArmed: Bool {
    state == .armed
  }

  /// Icon opacity: 0 when idle, scales with progress
  private var iconOpacity: CGFloat {
    switch state {
    case .idle:
      return 0
    case .pulling(let p):
      return p
    case .armed:
      return 1
    }
  }

  /// Icon scale: starts at 0.6, grows to 1.0 at full progress
  private var iconScale: CGFloat {
    if reduceMotion {
      return progress > 0 ? 1.0 : 0.6
    }
    return 0.6 + (0.4 * progress)
  }

  /// Vertical offset based on pull progress (linear tracking)
  private var iconOffset: CGFloat {
    // Pull threshold determines max offset
    let threshold = DS.Spacing.searchPullThreshold
    return progress * threshold
  }

  /// Accessibility label based on state
  private var accessibilityText: String {
    switch state {
    case .idle:
      return "Pull down to search"
    case .pulling:
      return "Pull down to search"
    case .armed:
      return "Release to search"
    }
  }
}

// MARK: - Preview

#if DEBUG
#Preview("Idle") {
  VStack {
    PullToSearchIndicator(state: .idle)
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(DS.Colors.Background.primary)
}

#Preview("Pulling 50%") {
  VStack {
    PullToSearchIndicator(state: .pulling(progress: 0.5))
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(DS.Colors.Background.primary)
}

#Preview("Armed") {
  VStack {
    PullToSearchIndicator(state: .armed)
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(DS.Colors.Background.primary)
}
#endif
