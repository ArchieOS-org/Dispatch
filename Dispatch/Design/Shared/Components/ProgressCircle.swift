//
//  ProgressCircle.swift
//  Dispatch
//
//  Shared Component - Circular progress indicator ring
//  Created by Claude on 2025-12-13.
//

import SwiftUI

/// A circular progress indicator that displays completion as a ring that fills.
/// The ring starts at 12 o'clock and fills clockwise based on progress value.
///
/// Usage:
/// ```swift
/// ProgressCircle(progress: 0.75)           // 75% filled
/// ProgressCircle(progress: listing.progress, size: 20)
/// ```
struct ProgressCircle: View {

  // MARK: Internal

  /// Progress value from 0.0 to 1.0
  let progress: Double

  /// Diameter of the circle (default 18pt for inline-with-title use)
  var size: CGFloat = 18

  /// Thickness of the ring stroke (default 2.5pt)
  var lineWidth: CGFloat = 2.5

  var body: some View {
    ZStack {
      // Track ring (background)
      Circle()
        .stroke(
          DS.Colors.Progress.track,
          style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )

      // Progress arc (fills from top, clockwise)
      Circle()
        .trim(from: 0, to: clampedProgress)
        .stroke(
          DS.Colors.accent,
          style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )
        .rotationEffect(.degrees(-90)) // Start from 12 o'clock
        .animation(.easeInOut(duration: 0.2), value: clampedProgress)
    }
    .frame(width: size, height: size)
    .accessibilityLabel("Progress: \(Int(clampedProgress * 100)) percent complete")
  }

  // MARK: Private

  /// Defensive clamping to handle out-of-bounds values
  private var clampedProgress: Double {
    min(max(progress, 0), 1)
  }

}

// MARK: - Preview

#Preview("Progress Circle States") {
  VStack(spacing: DS.Spacing.xl) {
    Text("Progress Circle").font(DS.Typography.headline)

    HStack(spacing: DS.Spacing.lg) {
      VStack(spacing: DS.Spacing.xs) {
        ProgressCircle(progress: 0)
        Text("0%").font(DS.Typography.caption)
      }
      VStack(spacing: DS.Spacing.xs) {
        ProgressCircle(progress: 0.25)
        Text("25%").font(DS.Typography.caption)
      }
      VStack(spacing: DS.Spacing.xs) {
        ProgressCircle(progress: 0.5)
        Text("50%").font(DS.Typography.caption)
      }
      VStack(spacing: DS.Spacing.xs) {
        ProgressCircle(progress: 0.75)
        Text("75%").font(DS.Typography.caption)
      }
      VStack(spacing: DS.Spacing.xs) {
        ProgressCircle(progress: 1.0)
        Text("100%").font(DS.Typography.caption)
      }
    }

    Divider()

    Text("Sizes").font(DS.Typography.headline)

    HStack(spacing: DS.Spacing.lg) {
      VStack(spacing: DS.Spacing.xs) {
        ProgressCircle(progress: 0.6, size: 14)
        Text("14pt").font(DS.Typography.caption)
      }
      VStack(spacing: DS.Spacing.xs) {
        ProgressCircle(progress: 0.6, size: 18)
        Text("18pt").font(DS.Typography.caption)
      }
      VStack(spacing: DS.Spacing.xs) {
        ProgressCircle(progress: 0.6, size: 24)
        Text("24pt").font(DS.Typography.caption)
      }
      VStack(spacing: DS.Spacing.xs) {
        ProgressCircle(progress: 0.6, size: 32)
        Text("32pt").font(DS.Typography.caption)
      }
    }

    Divider()

    Text("Inline with Text").font(DS.Typography.headline)

    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
      ProgressCircle(progress: 0.4, size: 20)
        .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 2 }
      Text("123 Main Street")
        .font(.title.bold())
    }

    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
      ProgressCircle(progress: 0.8, size: 20)
        .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 2 }
      Text("456 Oak Avenue with a Very Long Address Name")
        .font(.title.bold())
    }
  }
  .padding()
}

#Preview("Edge Cases") {
  VStack(spacing: DS.Spacing.lg) {
    Text("Edge Cases").font(DS.Typography.headline)

    HStack(spacing: DS.Spacing.lg) {
      VStack(spacing: DS.Spacing.xs) {
        ProgressCircle(progress: -0.5)
        Text("< 0 (clamped)").font(DS.Typography.caption)
      }
      VStack(spacing: DS.Spacing.xs) {
        ProgressCircle(progress: 1.5)
        Text("> 1 (clamped)").font(DS.Typography.caption)
      }
      VStack(spacing: DS.Spacing.xs) {
        ProgressCircle(progress: 0.001)
        Text("~0%").font(DS.Typography.caption)
      }
      VStack(spacing: DS.Spacing.xs) {
        ProgressCircle(progress: 0.999)
        Text("~100%").font(DS.Typography.caption)
      }
    }
  }
  .padding()
}
