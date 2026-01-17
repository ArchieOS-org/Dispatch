//
//  DraftRow.swift
//  Dispatch
//
//  Row component for displaying a Listing Generator draft.
//

import SwiftUI

// MARK: - DraftRow

/// A row displaying a Listing Generator draft.
/// Shows draft name, date, and output indicator.
struct DraftRow: View {

  // MARK: Lifecycle

  init(draft: ListingGeneratorDraft) {
    self.draft = draft
  }

  // MARK: Internal

  let draft: ListingGeneratorDraft

  var body: some View {
    HStack(spacing: DS.Spacing.md) {
      // Icon
      Image(systemName: draft.hasOutput ? "doc.text.fill" : "doc.text")
        .font(.system(size: 20))
        .foregroundStyle(draft.hasOutput ? DS.Colors.accent : DS.Colors.Text.tertiary)
        .frame(width: 28)
        .accessibilityHidden(true)

      // Content
      VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
        Text(draft.name)
          .font(DS.Typography.headline)
          .foregroundStyle(DS.Colors.Text.primary)
          .lineLimit(1)

        HStack(spacing: DS.Spacing.xs) {
          // Date
          Text(formattedDate)
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Colors.Text.secondary)

          // Output indicator
          if draft.hasOutput {
            Text("Generated")
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Colors.success)
          }
        }
      }

      Spacer()

      // Chevron
      Image(systemName: DS.Icons.Navigation.forward)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(DS.Colors.Text.tertiary)
        .accessibilityHidden(true)
    }
    .padding(.vertical, DS.Spacing.sm)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
  }

  // MARK: Private

  private var formattedDate: String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: draft.updatedAt, relativeTo: Date())
  }

  private var accessibilityLabel: String {
    var label = "Draft: \(draft.name), updated \(formattedDate)"
    if draft.hasOutput {
      label += ", generated"
    }
    return label
  }
}

// MARK: - Preview

#Preview("Draft Row - With Output") {
  let draft = ListingGeneratorDraft(
    name: "123 Main Street",
    inputStateData: Data(),
    hasOutput: true
  )

  return List {
    DraftRow(draft: draft)
  }
  .listStyle(.plain)
}

#Preview("Draft Row - No Output") {
  let draft = ListingGeneratorDraft(
    name: "456 Oak Avenue",
    inputStateData: Data(),
    hasOutput: false
  )

  return List {
    DraftRow(draft: draft)
  }
  .listStyle(.plain)
}

#Preview("Draft Row - Untitled") {
  let draft = ListingGeneratorDraft(
    name: "Untitled Draft",
    inputStateData: Data(),
    hasOutput: false
  )

  return List {
    DraftRow(draft: draft)
  }
  .listStyle(.plain)
}
