//
//  SettingsView.swift
//  Dispatch
//
//  Main Settings entry point for admin configuration.
//  Part of Listing Types & Activity Templates feature.
//

import SwiftData
import SwiftUI

// MARK: - SettingsView

/// Root Settings view for admins.
/// Access Control: Only visible to admin users.
struct SettingsView: View {
  var body: some View {
    StandardScreen(title: "Settings", layout: .column, scroll: .disabled) {
      StandardList(SettingsSection.allCases) { section in
        ListRowLink(value: AppRoute.settings(section)) {
          SettingsRow(section: section)
        }
      }
    }
    .environment(\.pullToSearchDisabled, true)
  }

  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var syncManager: SyncManager

}

// MARK: - SettingsSection

enum SettingsSection: String, Identifiable, CaseIterable {
  case listingTypes = "listing_types"
  case listingDraftDemo = "listing_draft_demo"

  // MARK: Internal

  var id: String {
    rawValue
  }

  var title: String {
    switch self {
    case .listingTypes: "Listing Types"
    case .listingDraftDemo: "Draft Preview"
    }
  }

  var icon: String {
    switch self {
    case .listingTypes: DS.Icons.Entity.listing
    case .listingDraftDemo: "doc.richtext"
    }
  }

  var description: String {
    switch self {
    case .listingTypes: "Configure listing types and auto-generated activities"
    case .listingDraftDemo: "Preview the listing draft editor (demo)"
    }
  }
}

// MARK: - SettingsRow

private struct SettingsRow: View {
  let section: SettingsSection

  var body: some View {
    HStack(spacing: DS.Spacing.md) {
      Circle()
        .fill(DS.Colors.Background.secondary)
        .frame(width: 40, height: 40)
        .overlay {
          Image(systemName: section.icon)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(DS.Colors.Text.primary)
        }

      VStack(alignment: .leading, spacing: 2) {
        Text(section.title)
          .font(DS.Typography.body)
          .foregroundStyle(DS.Colors.Text.primary)

        Text(section.description)
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.secondary)
      }

      Spacer()
    }
    .padding(.vertical, DS.Spacing.md)
    .contentShape(Rectangle())
  }
}

// MARK: - Preview

#Preview {
  PreviewShell { _ in
    // Seed with a sample user
  } content: { _ in
    SettingsView()
  }
}
