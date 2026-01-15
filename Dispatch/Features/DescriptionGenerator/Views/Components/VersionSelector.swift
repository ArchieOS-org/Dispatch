//
//  VersionSelector.swift
//  Dispatch
//
//  A/B version toggle selector for comparing generated outputs.
//  Provides clear visual feedback for selected version.
//

import SwiftUI

// MARK: - VersionSelector

/// Toggle control for selecting between A/B output versions.
/// Displays both options with clear selection state.
struct VersionSelector: View {

  // MARK: Internal

  /// Binding to the currently selected version
  @Binding var selectedVersion: OutputVersion?

  /// Callback when selection changes
  var onSelectionChanged: ((OutputVersion) -> Void)?

  var body: some View {
    HStack(spacing: 0) {
      ForEach(Array(OutputVersion.allCases.enumerated()), id: \.element) { index, version in
        if index > 0 {
          Divider()
            .frame(height: 24)
        }
        versionButton(version)
      }
    }
    .background(DS.Colors.Background.secondary)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium))
    .overlay(
      RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium)
        .stroke(DS.Colors.border, lineWidth: 1)
    )
  }

  // MARK: Private

  @ViewBuilder
  private func versionButton(_ version: OutputVersion) -> some View {
    let isSelected = selectedVersion == version

    Button {
      withAnimation(.easeInOut(duration: 0.2)) {
        selectedVersion = version
        onSelectionChanged?(version)
      }
    } label: {
      VStack(spacing: DS.Spacing.xxs) {
        Text(version.shortLabel)
          .font(DS.Typography.headline)
          .fontWeight(.semibold)

        Text(version.toneDescription)
          .font(DS.Typography.captionSecondary)
          .lineLimit(1)
      }
      .foregroundStyle(isSelected ? .white : DS.Colors.Text.primary)
      .frame(maxWidth: .infinity)
      .padding(.vertical, DS.Spacing.sm)
      .padding(.horizontal, DS.Spacing.md)
      .background(isSelected ? DS.Colors.accent : Color.clear)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(version.rawValue), \(version.toneDescription)")
    .accessibilityHint(isSelected ? "Currently selected" : "Double tap to select")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

// MARK: - Preview

#Preview("Version Selector") {
  struct PreviewWrapper: View {
    @State private var selected: OutputVersion? = .a

    var body: some View {
      VStack(spacing: DS.Spacing.xl) {
        VersionSelector(selectedVersion: $selected)

        Text("Selected: \(selected?.rawValue ?? "None")")
          .font(DS.Typography.caption)
      }
      .padding()
    }
  }

  return PreviewWrapper()
}
