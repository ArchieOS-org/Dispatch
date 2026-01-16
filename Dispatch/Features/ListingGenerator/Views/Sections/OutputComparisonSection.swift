//
//  OutputComparisonSection.swift
//  Dispatch
//
//  Side-by-side (or stacked) comparison of A/B generated outputs.
//  Responsive layout adapts to screen width.
//

import SwiftUI

// MARK: - OutputComparisonSection

/// Section displaying A/B output comparison with selection.
/// Adapts layout based on available width.
struct OutputComparisonSection: View {

  // MARK: Internal

  /// Generated output version A
  let outputA: GeneratedOutput?

  /// Generated output version B
  let outputB: GeneratedOutput?

  /// Currently selected version
  @Binding var selectedVersion: OutputVersion?

  /// Callback when user selects a version
  var onSelect: ((OutputVersion) -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.md) {
      // Section header
      headerSection

      // Comparison content
      if let a = outputA, let b = outputB {
        comparisonContent(outputA: a, outputB: b)
      } else {
        emptyState
      }
    }
    .padding(DS.Spacing.cardPadding)
    .background(DS.Colors.Background.card)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusCard))
  }

  // MARK: Private

  @ViewBuilder
  private var headerSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
      Text("Compare Versions")
        .font(DS.Typography.headline)
        .foregroundStyle(DS.Colors.Text.primary)

      Text("Select your preferred tone and style")
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.secondary)
    }
  }

  @ViewBuilder
  private var emptyState: some View {
    VStack(spacing: DS.Spacing.md) {
      Image(systemName: "sparkles")
        .font(.system(size: 32))
        .foregroundStyle(DS.Colors.Text.tertiary)
        .accessibilityHidden(true)

      Text("Generate descriptions to compare versions")
        .font(DS.Typography.body)
        .foregroundStyle(DS.Colors.Text.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, DS.Spacing.xxl)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Comparison area. Generate descriptions to compare versions.")
  }

  @ViewBuilder
  private func comparisonContent(outputA: GeneratedOutput, outputB: GeneratedOutput) -> some View {
    // Stacked layout - avoids GeometryReader issues in ScrollView
    // Side-by-side handled at parent level via platform layouts
    VStack(spacing: DS.Spacing.md) {
      outputCard(outputA)
      outputCard(outputB)
    }
  }

  @ViewBuilder
  private func outputCard(_ output: GeneratedOutput) -> some View {
    OutputCard(
      output: output,
      onSelect: {
        withAnimation(.easeInOut(duration: 0.2)) {
          selectedVersion = output.version
          onSelect?(output.version)
        }
      }
    )
    .frame(maxWidth: .infinity)
  }

}

// MARK: - ResponsiveOutputComparison

/// Responsive wrapper that handles layout switching automatically.
struct ResponsiveOutputComparison: View {

  // MARK: Internal

  let outputA: GeneratedOutput?
  let outputB: GeneratedOutput?
  @Binding var selectedVersion: OutputVersion?
  var onSelect: ((OutputVersion) -> Void)?

  var body: some View {
    GeometryReader { geometry in
      #if os(macOS)
      // macOS: Always side-by-side if wide enough
      if geometry.size.width > 800 {
        sideBySideLayout
      } else {
        stackedLayout
      }
      #else
      // iOS: Based on size class
      if horizontalSizeClass == .regular, geometry.size.width > 600 {
        sideBySideLayout
      } else {
        stackedLayout
      }
      #endif
    }
  }

  // MARK: Private

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @ViewBuilder
  private var sideBySideLayout: some View {
    HStack(alignment: .top, spacing: DS.Spacing.lg) {
      if let a = outputA {
        OutputCard(
          output: a,
          onSelect: { selectVersion(.a) }
        )
      }
      if let b = outputB {
        OutputCard(
          output: b,
          onSelect: { selectVersion(.b) }
        )
      }
    }
  }

  @ViewBuilder
  private var stackedLayout: some View {
    VStack(spacing: DS.Spacing.md) {
      if let a = outputA {
        OutputCard(
          output: a,
          onSelect: { selectVersion(.a) }
        )
      }
      if let b = outputB {
        OutputCard(
          output: b,
          onSelect: { selectVersion(.b) }
        )
      }
    }
  }

  private func selectVersion(_ version: OutputVersion) {
    withAnimation(.easeInOut(duration: 0.2)) {
      selectedVersion = version
      onSelect?(version)
    }
  }
}

// MARK: - Preview

#Preview("Output Comparison - With Data") {
  struct PreviewWrapper: View {
    @State private var selected: OutputVersion? = .a

    var body: some View {
      let outputA = GeneratedOutput(
        version: .a,
        mlsFields: .mockProfessional,
        isSelected: selected == .a
      )
      let outputB = GeneratedOutput(
        version: .b,
        mlsFields: .mockWarm,
        isSelected: selected == .b
      )

      return ScrollView {
        OutputComparisonSection(
          outputA: outputA,
          outputB: outputB,
          selectedVersion: $selected
        )
        .padding()
      }
    }
  }

  return PreviewWrapper()
}

#Preview("Output Comparison - Empty") {
  struct PreviewWrapper: View {
    @State private var selected: OutputVersion?

    var body: some View {
      OutputComparisonSection(
        outputA: nil,
        outputB: nil,
        selectedVersion: $selected
      )
      .padding()
    }
  }

  return PreviewWrapper()
}
