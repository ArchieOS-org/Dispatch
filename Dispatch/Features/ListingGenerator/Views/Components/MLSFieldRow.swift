//
//  MLSFieldRow.swift
//  Dispatch
//
//  Single MLS field display with label, value, copy button, and edit mode.
//  Supports inline editing and reset to generated value.
//

import SwiftUI

// MARK: - MLSFieldRow

/// Row component for displaying and editing a single MLS field.
/// Includes copy-to-clipboard functionality and reset option.
struct MLSFieldRow: View {

  // MARK: Internal

  /// Label for the field
  let label: String

  /// Binding to the field value
  @Binding var value: String

  /// Original generated value (for reset functionality)
  let originalValue: String

  /// Whether this is a multi-line field (uses TextEditor)
  var isMultiline: Bool = false

  /// Callback when value is copied
  var onCopy: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
      // Label row with actions
      HStack {
        Text(label)
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.tertiary)

        Spacer()

        // Actions
        HStack(spacing: DS.Spacing.sm) {
          // Reset button (only if edited)
          if value != originalValue {
            Button {
              withAnimation(.easeInOut(duration: 0.2)) {
                value = originalValue
              }
            } label: {
              Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 12))
                .foregroundStyle(DS.Colors.Text.tertiary)
            }
            .buttonStyle(.plain)
            .frame(minWidth: DS.Spacing.minTouchTarget, minHeight: DS.Spacing.minTouchTarget)
            .contentShape(Rectangle())
            .accessibilityLabel("Reset \(label) to generated value")
            .accessibilityHint("Double tap to restore the original generated text")
          }

          // Copy button
          Button {
            copyToClipboard()
          } label: {
            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
              .font(.system(size: 12))
              .foregroundStyle(showCopied ? DS.Colors.success : DS.Colors.Text.secondary)
          }
          .buttonStyle(.plain)
          .frame(minWidth: DS.Spacing.minTouchTarget, minHeight: DS.Spacing.minTouchTarget)
          .contentShape(Rectangle())
          .accessibilityLabel("Copy \(label)")
          .accessibilityHint("Double tap to copy to clipboard")
        }
      }

      // Value field
      if isMultiline {
        multilineField
      } else {
        singleLineField
      }
    }
  }

  // MARK: Private

  @State private var showCopied = false
  @FocusState private var isFocused: Bool

  @ViewBuilder
  private var singleLineField: some View {
    TextField(label, text: $value)
      .font(DS.Typography.body)
      .foregroundStyle(DS.Colors.Text.primary)
      .textFieldStyle(.plain)
      .focused($isFocused)
      .padding(DS.Spacing.sm)
      .background(DS.Colors.Background.secondary)
      .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall))
      .overlay(
        RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall)
          .stroke(isFocused ? DS.Colors.borderFocused : DS.Colors.border, lineWidth: 1)
      )
      .animation(.easeInOut(duration: 0.15), value: isFocused)
  }

  @ViewBuilder
  private var multilineField: some View {
    TextEditor(text: $value)
      .font(DS.Typography.body)
      .foregroundStyle(DS.Colors.Text.primary)
      .scrollContentBackground(.hidden)
      .focused($isFocused)
      .frame(minHeight: 80, maxHeight: 200)
      .padding(DS.Spacing.sm)
      .background(DS.Colors.Background.secondary)
      .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall))
      .overlay(
        RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall)
          .stroke(isFocused ? DS.Colors.borderFocused : DS.Colors.border, lineWidth: 1)
      )
      .animation(.easeInOut(duration: 0.15), value: isFocused)
  }

  private func copyToClipboard() {
    guard !value.isEmpty else { return }

    CopyFeedback.copyToClipboard(value, label: label)

    // Show feedback
    withAnimation(.easeInOut(duration: 0.2)) {
      showCopied = true
    }

    onCopy?()

    // Reset after delay using proper async pattern
    Task { @MainActor in
      await CopyFeedback.resetFeedbackFlag($showCopied, after: CopyFeedback.standardDelay)
    }
  }
}

// MARK: - MLSFieldRowCompact

/// Compact version of MLSFieldRow for inline display without editing.
struct MLSFieldRowCompact: View {

  // MARK: Internal

  let label: String
  let value: String
  var onCopy: (() -> Void)?

  var body: some View {
    HStack(alignment: .top, spacing: DS.Spacing.sm) {
      Text(label)
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.tertiary)
        .frame(width: 100, alignment: .leading)

      Text(value)
        .font(DS.Typography.body)
        .foregroundStyle(DS.Colors.Text.primary)
        .frame(maxWidth: .infinity, alignment: .leading)

      Button {
        copyToClipboard()
      } label: {
        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
          .font(.system(size: 12))
          .foregroundStyle(showCopied ? DS.Colors.success : DS.Colors.Text.secondary)
      }
      .buttonStyle(.plain)
      .frame(minWidth: DS.Spacing.minTouchTarget, minHeight: DS.Spacing.minTouchTarget)
      .contentShape(Rectangle())
      .accessibilityLabel("Copy \(label)")
      .accessibilityHint("Double tap to copy to clipboard")
    }
    .padding(.vertical, DS.Spacing.xs)
  }

  // MARK: Private

  @State private var showCopied = false

  private func copyToClipboard() {
    guard !value.isEmpty else { return }

    CopyFeedback.copyToClipboard(value, label: label)

    withAnimation(.easeInOut(duration: 0.2)) {
      showCopied = true
    }

    onCopy?()

    // Reset after delay using proper async pattern
    Task { @MainActor in
      await CopyFeedback.resetFeedbackFlag($showCopied, after: CopyFeedback.standardDelay)
    }
  }
}

// MARK: - Preview

#Preview("MLS Field Row - Single Line") {
  struct PreviewWrapper: View {
    @State private var value = "Single Family"

    var body: some View {
      MLSFieldRow(
        label: "Property Type",
        value: $value,
        originalValue: "Single Family"
      )
      .padding()
    }
  }

  return PreviewWrapper()
}

#Preview("MLS Field Row - Multiline") {
  struct PreviewWrapper: View {
    @State private var value = """
      This meticulously maintained 4-bedroom home offers refined living space \
      with premium finishes throughout.
      """

    var body: some View {
      MLSFieldRow(
        label: "Public Remarks",
        value: $value,
        originalValue: value,
        isMultiline: true
      )
      .padding()
    }
  }

  return PreviewWrapper()
}
