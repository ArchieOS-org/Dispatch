//
//  RealtimeDegradedIndicator.swift
//  Dispatch
//
//  Design System component for realtime degraded status indicator.
//  Shows when realtime subscriptions have failed and are in degraded mode.
//

import SwiftUI

/// A subtle indicator that shows when realtime is degraded.
/// Non-interactive visual indicator positioned near the offline indicator.
/// Uses a pulsing animation to indicate ongoing reconnection attempts.
struct RealtimeDegradedIndicator: View {

  // MARK: Internal

  var body: some View {
    HStack(spacing: DS.Spacing.xs) {
      Image(systemName: DS.Icons.Sync.error)
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Sync.error)
        .opacity(pulseOpacity)
        .animation(
          .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
          value: pulseOpacity
        )
      Text("Live updates paused")
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.secondary)
    }
    .padding(.horizontal, DS.Spacing.sm)
    .padding(.vertical, DS.Spacing.xs)
    .background(
      RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall)
        .fill(DS.Colors.Background.secondary)
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Live updates paused. Reconnecting in background.")
    .accessibilityAddTraits(.updatesFrequently)
    .onAppear {
      pulseOpacity = 0.4
    }
  }

  // MARK: Private

  @State private var pulseOpacity: Double = 1.0
}

#Preview {
  VStack {
    RealtimeDegradedIndicator()
    Spacer()
  }
  .padding()
}
