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

  // MARK: Internal

  var body: some View {
    StandardScreen(title: "Settings", layout: .column, scroll: .automatic) {
      VStack(spacing: DS.Spacing.lg) {
        // Profile Row (navigates to ProfilePageView)
        ProfileRow()

        // Admin Settings (only for admin users)
        if syncManager.currentUser?.userType == .admin {
          VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Admin")
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Colors.Text.secondary)
              .textCase(.uppercase)
              .padding(.horizontal, DS.Spacing.xs)

            VStack(spacing: 0) {
              ForEach(SettingsSection.allCases) { section in
                ListRowLink(value: AppRoute.settings(section)) {
                  SettingsRow(section: section)
                }
                if section != SettingsSection.allCases.last {
                  Divider()
                    .padding(.leading, 52)
                }
              }
            }
          }
        }
      }
      .padding(.vertical, DS.Spacing.sm)
    }
    .environment(\.pullToSearchDisabled, true)
    .onAppear { overlayState.hide(reason: .settingsScreen) }
    .onDisappear { overlayState.show(reason: .settingsScreen) }
  }

  // MARK: Private

  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var overlayState: AppOverlayState
  @EnvironmentObject private var syncManager: SyncManager

}

// MARK: - SettingsSection

enum SettingsSection: String, Identifiable, CaseIterable {
  case listingTypes = "listing_types"

  // MARK: Internal

  var id: String {
    rawValue
  }

  var title: String {
    switch self {
    case .listingTypes: "Listing Types"
    }
  }

  var icon: String {
    switch self {
    case .listingTypes: DS.Icons.Entity.listing
    }
  }

  var description: String {
    switch self {
    case .listingTypes: "Configure listing types and auto-generated activities"
    }
  }
}

// MARK: - ProfileRow

/// Summary row that navigates to the full ProfilePageView.
private struct ProfileRow: View {

  // MARK: Internal

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      Text("Account")
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.secondary)
        .textCase(.uppercase)
        .padding(.horizontal, DS.Spacing.xs)

      ListRowLink(value: AppRoute.profile) {
        HStack(spacing: DS.Spacing.md) {
          UserAvatar(user: currentUser, size: .large)

          VStack(alignment: .leading, spacing: 2) {
            Text(currentUser?.name ?? "Unknown")
              .font(DS.Typography.headline)
              .foregroundStyle(DS.Colors.Text.primary)
              .lineLimit(1)

            Text(currentUser?.userType.displayName ?? "")
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Colors.Text.secondary)
              .lineLimit(1)
          }

          Spacer()

          Image(systemName: "chevron.right")
            .font(.system(size: chevronIconSize, weight: .semibold))
            .foregroundStyle(DS.Colors.Text.tertiary)
        }
        .padding(DS.Spacing.md)
        .frame(minHeight: DS.Spacing.minTouchTarget)
        .contentShape(Rectangle())
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Profile: \(currentUser?.name ?? "Unknown"), \(currentUser?.userType.displayName ?? "")")
    .accessibilityHint("Tap to view and edit profile")
  }

  // MARK: Private

  /// Scaled chevron icon size for Dynamic Type support (base: 14pt)
  @ScaledMetric(relativeTo: .footnote)
  private var chevronIconSize: CGFloat = 14

  @EnvironmentObject private var syncManager: SyncManager

  private var currentUser: User? {
    syncManager.currentUser
  }

}

// MARK: - SettingsRow

private struct SettingsRow: View {

  // MARK: Internal

  let section: SettingsSection

  var body: some View {
    HStack(spacing: DS.Spacing.md) {
      Circle()
        .fill(DS.Colors.Background.secondary)
        .frame(width: 40, height: 40)
        .overlay {
          Image(systemName: section.icon)
            .font(.system(size: iconSize, weight: .medium))
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
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(section.title). \(section.description)")
  }

  // MARK: Private

  /// Scaled icon size for Dynamic Type support (base: 18pt)
  @ScaledMetric(relativeTo: .body)
  private var iconSize: CGFloat = 18

}

// MARK: - Preview

#Preview {
  PreviewShell { _ in
    // Seed with a sample user
  } content: { _ in
    SettingsView()
  }
}
