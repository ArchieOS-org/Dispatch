//
//  GenerationProgressView.swift
//  Dispatch
//
//  Minimal progress indicator showing the current generation phase.
//  Displays a spinner with calm, subtle text - not busy or anxiety-inducing.
//

import SwiftUI

// MARK: - GenerationProgressView

/// Shows the current generation phase with minimal animation.
/// Designed to be calm and confidence-inspiring, not busy.
struct GenerationProgressView: View {

  // MARK: Internal

  let phase: GenerationPhase

  var body: some View {
    if phase.showsProgress {
      HStack(spacing: DS.Spacing.sm) {
        ProgressView()
          .controlSize(.small)
        #if os(iOS)
          .tint(.white)
        #endif

        Text(phase.displayText)
          .font(DS.Typography.headline)
          .foregroundStyle(textColor)
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(phase.displayText)
      .accessibilityAddTraits(.updatesFrequently)
    }
  }

  // MARK: Private

  private var textColor: Color {
    #if os(iOS)
    .white
    #else
    DS.Colors.Text.primary
    #endif
  }
}

// MARK: - Preview

#Preview("Generation Progress - Fetching Report") {
  VStack(spacing: DS.Spacing.lg) {
    GenerationProgressView(phase: .fetchingReport(.geoWarehouse))
    GenerationProgressView(phase: .fetchingReport(.mpac))
    GenerationProgressView(phase: .extractingFromImages)
    GenerationProgressView(phase: .generatingDescriptions)
  }
  .padding()
  .background(DS.Colors.accent)
}

#Preview("Generation Progress - Idle") {
  GenerationProgressView(phase: .idle)
    .padding()
    .background(DS.Colors.Background.card)
}
