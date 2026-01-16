//
//  FetchedReportRow.swift
//  Dispatch
//
//  Displays a fetched report in the output section.
//  Shows checkmark, report name, and expandable summary.
//

import SwiftUI

// MARK: - FetchedReportRow

/// Row showing a fetched report with ability to expand and view summary.
/// Minimal design that doesn't compete with the main description output.
struct FetchedReportRow: View {

  // MARK: Internal

  let report: FetchedReport
  let onToggleExpand: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header row
      Button(action: onToggleExpand) {
        HStack(spacing: DS.Spacing.sm) {
          // Checkmark
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(DS.Colors.success)
            .accessibilityHidden(true)

          // Report icon
          Image(systemName: report.type.icon)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(DS.Colors.Text.secondary)
            .accessibilityHidden(true)

          // Report name
          Text(report.type.displayName)
            .font(DS.Typography.body)
            .foregroundStyle(DS.Colors.Text.primary)

          Spacer()

          // Expand/collapse chevron
          Image(systemName: report.isExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(DS.Colors.Text.tertiary)
            .accessibilityHidden(true)
        }
        .frame(minHeight: 20)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(report.type.displayName) report")
      .accessibilityHint(report.isExpanded ? "Double tap to collapse" : "Double tap to expand")
      .accessibilityAddTraits(.isButton)

      // Expanded summary
      if report.isExpanded {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
          Divider()
            .padding(.vertical, DS.Spacing.sm)

          Text(report.mockSummary)
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Colors.Text.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .padding(DS.Spacing.md)
    .background(DS.Colors.Background.secondary)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall))
    .animation(.easeInOut(duration: 0.2), value: report.isExpanded)
  }
}

// MARK: - Preview

#Preview("Fetched Report - Collapsed") {
  VStack(spacing: DS.Spacing.sm) {
    FetchedReportRow(
      report: FetchedReport(type: .geoWarehouse, isExpanded: false),
      onToggleExpand: { }
    )
    FetchedReportRow(
      report: FetchedReport(type: .mpac, isExpanded: false),
      onToggleExpand: { }
    )
  }
  .padding()
  .background(DS.Colors.Background.card)
}

#Preview("Fetched Report - Expanded") {
  FetchedReportRow(
    report: FetchedReport(type: .geoWarehouse, isExpanded: true),
    onToggleExpand: { }
  )
  .padding()
  .background(DS.Colors.Background.card)
}
