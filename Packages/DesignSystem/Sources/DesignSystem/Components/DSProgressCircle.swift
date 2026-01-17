//
//  DSProgressCircle.swift
//  DesignSystem
//
//  Circular progress indicator ring.
//  Ring starts at 12 o'clock and fills clockwise.
//

import SwiftUI

/// A circular progress indicator that displays completion as a ring that fills.
/// The ring starts at 12 o'clock and fills clockwise based on progress value.
///
/// Usage:
/// ```swift
/// DSProgressCircle(progress: 0.75)           // 75% filled
/// DSProgressCircle(progress: 0.5, size: 24)  // Larger size
/// ```
public struct DSProgressCircle: View {

  // MARK: Lifecycle

  /// Creates a progress circle.
  /// - Parameters:
  ///   - progress: Progress value from 0.0 to 1.0. Values outside range are clamped.
  ///   - size: Diameter of the circle. Defaults to 18pt.
  ///   - lineWidth: Thickness of the ring stroke. Defaults to 2.5pt.
  ///   - trackColor: Color of the background track. Defaults to tertiary text at 30% opacity.
  ///   - progressColor: Color of the progress arc. Defaults to accent color.
  public init(
    progress: Double,
    size: CGFloat = 18,
    lineWidth: CGFloat = 2.5,
    trackColor: Color = DS.Colors.Progress.track,
    progressColor: Color = DS.Colors.accent
  ) {
    self.progress = progress
    self.size = size
    self.lineWidth = lineWidth
    self.trackColor = trackColor
    self.progressColor = progressColor
  }

  // MARK: Public

  public var body: some View {
    ZStack {
      // Track ring (background)
      Circle()
        .stroke(
          trackColor,
          style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )

      // Progress arc (fills from top, clockwise)
      Circle()
        .trim(from: 0, to: clampedProgress)
        .stroke(
          progressColor,
          style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )
        .rotationEffect(.degrees(-90)) // Start from 12 o'clock
        .animation(.easeInOut(duration: 0.2), value: clampedProgress)
    }
    .frame(width: size, height: size)
    .accessibilityLabel("Progress: \(Int(clampedProgress * 100)) percent complete")
  }

  // MARK: Internal

  let progress: Double
  let size: CGFloat
  let lineWidth: CGFloat
  let trackColor: Color
  let progressColor: Color

  // MARK: Private

  /// Defensive clamping to handle out-of-bounds values
  private var clampedProgress: Double {
    min(max(progress, 0), 1)
  }

}

// MARK: - Preview

#Preview("DSProgressCircle - States") {
  VStack(spacing: DS.Spacing.xl) {
    Text("Progress States").font(DS.Typography.headline)

    HStack(spacing: DS.Spacing.lg) {
      VStack(spacing: DS.Spacing.xs) {
        DSProgressCircle(progress: 0)
        Text("0%").font(DS.Typography.caption)
      }
      VStack(spacing: DS.Spacing.xs) {
        DSProgressCircle(progress: 0.25)
        Text("25%").font(DS.Typography.caption)
      }
      VStack(spacing: DS.Spacing.xs) {
        DSProgressCircle(progress: 0.5)
        Text("50%").font(DS.Typography.caption)
      }
      VStack(spacing: DS.Spacing.xs) {
        DSProgressCircle(progress: 0.75)
        Text("75%").font(DS.Typography.caption)
      }
      VStack(spacing: DS.Spacing.xs) {
        DSProgressCircle(progress: 1.0)
        Text("100%").font(DS.Typography.caption)
      }
    }
  }
  .padding()
}

#Preview("DSProgressCircle - Sizes") {
  VStack(spacing: DS.Spacing.xl) {
    Text("Sizes").font(DS.Typography.headline)

    HStack(spacing: DS.Spacing.lg) {
      VStack(spacing: DS.Spacing.xs) {
        DSProgressCircle(progress: 0.6, size: 14)
        Text("14pt").font(DS.Typography.caption)
      }
      VStack(spacing: DS.Spacing.xs) {
        DSProgressCircle(progress: 0.6, size: 18)
        Text("18pt").font(DS.Typography.caption)
      }
      VStack(spacing: DS.Spacing.xs) {
        DSProgressCircle(progress: 0.6, size: 24)
        Text("24pt").font(DS.Typography.caption)
      }
      VStack(spacing: DS.Spacing.xs) {
        DSProgressCircle(progress: 0.6, size: 32)
        Text("32pt").font(DS.Typography.caption)
      }
    }
  }
  .padding()
}

#Preview("DSProgressCircle - Colors") {
  VStack(spacing: DS.Spacing.xl) {
    Text("Custom Colors").font(DS.Typography.headline)

    HStack(spacing: DS.Spacing.lg) {
      DSProgressCircle(progress: 0.7, progressColor: .green)
      DSProgressCircle(progress: 0.7, progressColor: .orange)
      DSProgressCircle(progress: 0.7, progressColor: .red)
      DSProgressCircle(progress: 0.7, progressColor: .purple)
    }
  }
  .padding()
}

#Preview("DSProgressCircle - Inline with Text") {
  VStack(spacing: DS.Spacing.lg) {
    Text("Inline with Text").font(DS.Typography.headline)

    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
      DSProgressCircle(progress: 0.4, size: 20)
        .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 2 }
      Text("123 Main Street")
        .font(.title.bold())
    }

    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
      DSProgressCircle(progress: 0.8, size: 20)
        .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 2 }
      Text("456 Oak Avenue")
        .font(.title.bold())
    }
  }
  .padding()
}

#Preview("DSProgressCircle - Edge Cases") {
  VStack(spacing: DS.Spacing.lg) {
    Text("Edge Cases").font(DS.Typography.headline)

    HStack(spacing: DS.Spacing.lg) {
      VStack(spacing: DS.Spacing.xs) {
        DSProgressCircle(progress: -0.5)
        Text("< 0").font(DS.Typography.caption)
      }
      VStack(spacing: DS.Spacing.xs) {
        DSProgressCircle(progress: 1.5)
        Text("> 1").font(DS.Typography.caption)
      }
      VStack(spacing: DS.Spacing.xs) {
        DSProgressCircle(progress: 0.001)
        Text("~0%").font(DS.Typography.caption)
      }
      VStack(spacing: DS.Spacing.xs) {
        DSProgressCircle(progress: 0.999)
        Text("~100%").font(DS.Typography.caption)
      }
    }
  }
  .padding()
}
