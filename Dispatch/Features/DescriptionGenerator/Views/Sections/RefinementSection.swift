//
//  RefinementSection.swift
//  Dispatch
//
//  Prompt-based refinement of selected AI output.
//  Includes suggestion chips and refinement history.
//

import SwiftUI

// MARK: - RefinementSection

/// Section for refining the selected output with prompt-based instructions.
/// Shows suggestion chips and maintains refinement history.
struct RefinementSection: View {

  // MARK: Internal

  /// Binding to the current refinement prompt
  @Binding var prompt: String

  /// Refinement history
  let history: [RefinementRequest]

  /// Whether refinement is in progress
  let isRefining: Bool

  /// Whether an output is selected (refinement requires selection)
  let hasSelectedOutput: Bool

  /// Callback when refinement is submitted
  var onSubmit: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.md) {
      // Section header
      headerSection

      // Prompt input
      promptInput

      // Suggestion chips
      if prompt.isEmpty {
        suggestionChips
      }

      // Submit button
      submitButton

      // Refinement history
      if !history.isEmpty {
        refinementHistory
      }
    }
    .padding(DS.Spacing.cardPadding)
    .background(DS.Colors.Background.card)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusCard))
  }

  // MARK: Private

  @State private var showHistory = false

  private let suggestions = [
    "Make it more luxurious",
    "Emphasize the view",
    "Shorter description",
    "More family-friendly",
    "Highlight outdoor spaces",
    "Focus on investment potential"
  ]

  @ViewBuilder
  private var headerSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
      Text("Refine Output")
        .font(DS.Typography.headline)
        .foregroundStyle(DS.Colors.Text.primary)

      Text("Give instructions to improve the generated description")
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.secondary)
    }
  }

  @ViewBuilder
  private var promptInput: some View {
    HStack(alignment: .top, spacing: DS.Spacing.sm) {
      TextEditor(text: $prompt)
        .font(DS.Typography.body)
        .foregroundStyle(DS.Colors.Text.primary)
        .scrollContentBackground(.hidden)
        .frame(minHeight: 60, maxHeight: 120)
        .padding(DS.Spacing.sm)
        .background(DS.Colors.Background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium))
        .overlay(
          RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium)
            .stroke(DS.Colors.border, lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
          // Use opacity instead of conditional for stable layout
          Text("e.g., Make it more luxurious...")
            .font(DS.Typography.body)
            .foregroundStyle(DS.Colors.Text.placeholder)
            .padding(.horizontal, DS.Spacing.sm + 4)
            .padding(.vertical, DS.Spacing.sm + 8)
            .allowsHitTesting(false)
            .opacity(prompt.isEmpty ? 1 : 0)
        }
        .disabled(!hasSelectedOutput)
        .opacity(hasSelectedOutput ? 1 : 0.6)
    }
  }

  @ViewBuilder
  private var suggestionChips: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      Text("Try a suggestion:")
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.tertiary)

      FlowLayout(spacing: DS.Spacing.sm) {
        ForEach(suggestions, id: \.self) { suggestion in
          suggestionChip(suggestion)
        }
      }
    }
    .opacity(hasSelectedOutput ? 1 : 0.6)
  }

  @ViewBuilder
  private var submitButton: some View {
    Button {
      onSubmit?()
    } label: {
      HStack(spacing: DS.Spacing.sm) {
        if isRefining {
          ProgressView()
            .controlSize(.small)
          #if os(iOS)
            .tint(.white)
          #endif
        }
        Text(isRefining ? "Refining..." : "Refine")
          .font(DS.Typography.headline)
      }
      .frame(maxWidth: .infinity)
      .frame(height: DS.Spacing.minTouchTarget)
    }
    .buttonStyle(.borderedProminent)
    .disabled(!canSubmit)
    .accessibilityLabel(isRefining ? "Refining output" : "Submit refinement")
    .accessibilityHint(
      canSubmit
        ? "Double tap to refine with your instructions"
        : hasSelectedOutput
          ? "Enter refinement instructions first"
          : "Select an output version first"
    )
  }

  private var canSubmit: Bool {
    hasSelectedOutput &&
      !prompt.trimmingCharacters(in: .whitespaces).isEmpty &&
      !isRefining
  }

  @ViewBuilder
  private var refinementHistory: some View {
    DisclosureGroup(
      isExpanded: $showHistory
    ) {
      VStack(alignment: .leading, spacing: DS.Spacing.sm) {
        ForEach(history.reversed()) { request in
          historyRow(request)
        }
      }
      .padding(.top, DS.Spacing.sm)
    } label: {
      HStack(spacing: DS.Spacing.xs) {
        Image(systemName: "clock.arrow.circlepath")
          .font(.system(size: 14))
          .foregroundStyle(DS.Colors.Text.secondary)

        Text("Refinement History")
          .font(DS.Typography.callout)
          .foregroundStyle(DS.Colors.Text.primary)

        Spacer()

        Text("\(history.count)")
          .font(DS.Typography.captionSecondary)
          .foregroundStyle(DS.Colors.Text.tertiary)
          .padding(.horizontal, DS.Spacing.xs)
          .padding(.vertical, 2)
          .background(DS.Colors.Background.secondary)
          .clipShape(Capsule())
      }
    }
    .tint(DS.Colors.Text.secondary)
  }

  @ViewBuilder
  private func suggestionChip(_ text: String) -> some View {
    Button {
      prompt = text
    } label: {
      Text(text)
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.primary)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(DS.Colors.Background.secondary)
        .clipShape(Capsule())
        .overlay(
          Capsule()
            .stroke(DS.Colors.border, lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
    .disabled(!hasSelectedOutput)
    .accessibilityLabel("Use suggestion: \(text)")
  }

  @ViewBuilder
  private func historyRow(_ request: RefinementRequest) -> some View {
    HStack(alignment: .top, spacing: DS.Spacing.sm) {
      Image(systemName: "arrow.turn.down.right")
        .font(.system(size: 12))
        .foregroundStyle(DS.Colors.Text.tertiary)
        .padding(.top, 2)

      VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
        Text(request.prompt)
          .font(DS.Typography.body)
          .foregroundStyle(DS.Colors.Text.primary)

        Text(request.timestamp.formatted(date: .omitted, time: .shortened))
          .font(DS.Typography.captionSecondary)
          .foregroundStyle(DS.Colors.Text.tertiary)
      }

      Spacer()
    }
    .padding(DS.Spacing.sm)
    .background(DS.Colors.Background.secondary)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall))
  }
}

// MARK: - FlowLayout

/// Simple flow layout for suggestion chips.
/// Wraps content to next line when horizontal space is exhausted.
struct FlowLayout: Layout {

  // MARK: Lifecycle

  init(spacing: CGFloat = 8) {
    self.spacing = spacing
  }

  // MARK: Internal

  var spacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
    let result = arrange(proposal: proposal, subviews: subviews)
    return result.size
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
    let arrangement = arrange(proposal: proposal, subviews: subviews)

    for (index, subview) in subviews.enumerated() {
      let position = arrangement.positions[index]
      subview.place(
        at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
        proposal: .unspecified
      )
    }
  }

  // MARK: Private

  private struct ArrangementResult {
    var positions: [CGPoint]
    var size: CGSize
  }

  private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangementResult {
    let maxWidth = proposal.width ?? .infinity
    var positions: [CGPoint] = []
    var currentX: CGFloat = 0
    var currentY: CGFloat = 0
    var rowHeight: CGFloat = 0
    var maxX: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)

      if currentX + size.width > maxWidth, currentX > 0 {
        currentX = 0
        currentY += rowHeight + spacing
        rowHeight = 0
      }

      positions.append(CGPoint(x: currentX, y: currentY))
      rowHeight = max(rowHeight, size.height)
      currentX += size.width + spacing
      maxX = max(maxX, currentX - spacing)
    }

    return ArrangementResult(
      positions: positions,
      size: CGSize(width: maxX, height: currentY + rowHeight)
    )
  }
}

// MARK: - Preview

#Preview("Refinement Section - Empty") {
  struct PreviewWrapper: View {
    @State private var prompt = ""

    var body: some View {
      RefinementSection(
        prompt: $prompt,
        history: [],
        isRefining: false,
        hasSelectedOutput: true
      )
      .padding()
    }
  }

  return PreviewWrapper()
}

#Preview("Refinement Section - With History") {
  struct PreviewWrapper: View {
    @State private var prompt = ""

    var body: some View {
      RefinementSection(
        prompt: $prompt,
        history: [
          RefinementRequest(prompt: "Make it more luxurious"),
          RefinementRequest(prompt: "Emphasize the mountain views")
        ],
        isRefining: false,
        hasSelectedOutput: true
      )
      .padding()
    }
  }

  return PreviewWrapper()
}

#Preview("Refinement Section - Loading") {
  struct PreviewWrapper: View {
    @State private var prompt = "Add more about the backyard"

    var body: some View {
      RefinementSection(
        prompt: $prompt,
        history: [],
        isRefining: true,
        hasSelectedOutput: true
      )
      .padding()
    }
  }

  return PreviewWrapper()
}

#Preview("Refinement Section - No Selection") {
  struct PreviewWrapper: View {
    @State private var prompt = ""

    var body: some View {
      RefinementSection(
        prompt: $prompt,
        history: [],
        isRefining: false,
        hasSelectedOutput: false
      )
      .padding()
    }
  }

  return PreviewWrapper()
}
