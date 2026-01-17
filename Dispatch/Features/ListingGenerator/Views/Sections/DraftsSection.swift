//
//  DraftsSection.swift
//  Dispatch
//
//  Section component displaying saved Listing Generator drafts.
//  Provides navigation to resume drafts and delete functionality.
//

import SwiftData
import SwiftUI

// MARK: - DraftsSection

/// A section displaying saved Listing Generator drafts.
/// Supports navigation to resume drafts and swipe-to-delete.
struct DraftsSection: View {

  // MARK: Lifecycle

  init(
    drafts: [ListingGeneratorDraft],
    onNavigate: @escaping (UUID) -> Void,
    onDelete: @escaping (ListingGeneratorDraft) -> Void
  ) {
    self.drafts = drafts
    self.onNavigate = onNavigate
    self.onDelete = onDelete
  }

  // MARK: Internal

  let drafts: [ListingGeneratorDraft]
  let onNavigate: (UUID) -> Void
  let onDelete: (ListingGeneratorDraft) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Section Header
      SectionHeader("Listing Drafts") {
        Text("\(drafts.count)")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.tertiary)
      }

      Divider()
        .accessibilityHidden(true)
        .padding(.bottom, DS.Spacing.sm)

      // Draft rows
      ForEach(drafts) { draft in
        Button {
          onNavigate(draft.id)
        } label: {
          DraftRow(draft: draft)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
          Button(role: .destructive) {
            onDelete(draft)
          } label: {
            Label("Delete", systemImage: DS.Icons.Action.delete)
          }
        }
      }
    }
  }
}

// MARK: - DraftsSectionCard

/// A card-style version of DraftsSection for use outside of lists.
/// Provides the same functionality with card styling.
struct DraftsSectionCard: View {

  // MARK: Lifecycle

  init(
    drafts: [ListingGeneratorDraft],
    onNavigate: @escaping (UUID) -> Void,
    onDelete: @escaping (ListingGeneratorDraft) -> Void
  ) {
    self.drafts = drafts
    self.onNavigate = onNavigate
    self.onDelete = onDelete
  }

  // MARK: Internal

  let drafts: [ListingGeneratorDraft]
  let onNavigate: (UUID) -> Void
  let onDelete: (ListingGeneratorDraft) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      // Header
      HStack {
        Label("Listing Drafts", systemImage: "doc.text")
          .font(DS.Typography.headline)
          .foregroundStyle(DS.Colors.Text.primary)

        Spacer()

        Text("\(drafts.count)")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.tertiary)
          .padding(.horizontal, DS.Spacing.sm)
          .padding(.vertical, DS.Spacing.xxs)
          .background(DS.Colors.Background.secondary)
          .clipShape(Capsule())
      }

      Divider()

      // Drafts list (limited to first 3)
      ForEach(drafts.prefix(3)) { draft in
        Button {
          onNavigate(draft.id)
        } label: {
          DraftRow(draft: draft)
        }
        .buttonStyle(.plain)

        if draft.id != drafts.prefix(3).last?.id {
          Divider()
            .padding(.leading, 40)
        }
      }

      // "See All" link if more than 3 drafts
      if drafts.count > 3 {
        Divider()

        HStack {
          Spacer()
          Text("See all \(drafts.count) drafts")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Colors.accent)
          Image(systemName: DS.Icons.Navigation.forward)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(DS.Colors.accent)
          Spacer()
        }
        .padding(.top, DS.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("See all \(drafts.count) drafts")
        .accessibilityHint("Double tap to view all saved drafts")
      }
    }
    .padding(DS.Spacing.cardPadding)
    .background(DS.Colors.Background.card)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusCard))
  }
}

// MARK: - DraftsSectionPreview

private struct DraftsSectionPreview: View {

  // MARK: Internal

  var body: some View {
    List {
      DraftsSection(
        drafts: drafts,
        onNavigate: { _ in },
        onDelete: { draft in
          drafts.removeAll { $0.id == draft.id }
        }
      )
    }
    .listStyle(.plain)
  }

  // MARK: Private

  @State private var drafts = [
    ListingGeneratorDraft(
      name: "123 Main Street",
      inputStateData: Data(),
      hasOutput: true,
      updatedAt: Date().addingTimeInterval(-3600)
    ),
    ListingGeneratorDraft(
      name: "456 Oak Avenue",
      inputStateData: Data(),
      hasOutput: false,
      updatedAt: Date().addingTimeInterval(-86400)
    ),
    ListingGeneratorDraft(
      name: "789 Pine Road",
      inputStateData: Data(),
      hasOutput: true,
      updatedAt: Date().addingTimeInterval(-172800)
    )
  ]

}

#Preview("Drafts Section") {
  DraftsSectionPreview()
}

// MARK: - DraftsSectionCardPreview

private struct DraftsSectionCardPreview: View {
  let drafts = [
    ListingGeneratorDraft(
      name: "123 Main Street",
      inputStateData: Data(),
      hasOutput: true,
      updatedAt: Date().addingTimeInterval(-3600)
    ),
    ListingGeneratorDraft(
      name: "456 Oak Avenue",
      inputStateData: Data(),
      hasOutput: false,
      updatedAt: Date().addingTimeInterval(-86400)
    ),
    ListingGeneratorDraft(
      name: "789 Pine Road",
      inputStateData: Data(),
      hasOutput: true,
      updatedAt: Date().addingTimeInterval(-172800)
    ),
    ListingGeneratorDraft(
      name: "321 Elm Street",
      inputStateData: Data(),
      hasOutput: false,
      updatedAt: Date().addingTimeInterval(-259200)
    )
  ]

  var body: some View {
    ScrollView {
      VStack(spacing: DS.Spacing.lg) {
        DraftsSectionCard(
          drafts: drafts,
          onNavigate: { _ in },
          onDelete: { _ in }
        )
      }
      .padding(DS.Spacing.lg)
    }
    .background(DS.Colors.Background.grouped)
  }
}

#Preview("Drafts Section Card") {
  DraftsSectionCardPreview()
}

#Preview("Drafts Section Card - Empty") {
  ScrollView {
    VStack(spacing: DS.Spacing.lg) {
      DraftsSectionCard(
        drafts: [],
        onNavigate: { _ in },
        onDelete: { _ in }
      )
    }
    .padding(DS.Spacing.lg)
  }
  .background(DS.Colors.Background.grouped)
}
