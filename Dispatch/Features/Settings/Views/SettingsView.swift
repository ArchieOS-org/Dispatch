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
    StandardScreen(title: "Settings", layout: .column, scroll: .automatic) {
      VStack(spacing: DS.Spacing.lg) {
        // Profile Section
        ProfileSection()

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
            .background(DS.Colors.Background.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusCard))
          }
        }
      }
      .padding(.vertical, DS.Spacing.sm)
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

// MARK: - ProfileSection

private struct ProfileSection: View {

  @EnvironmentObject private var authManager: AuthManager
  @EnvironmentObject private var syncManager: SyncManager

  @State private var showingLogoutConfirmation = false
  @State private var showingTypeChangeConfirmation = false
  @State private var pendingUserType: UserType?
  @State private var isUpdatingType = false
  @State private var updateError: Error?

  private var currentUser: User? {
    syncManager.currentUser
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      Text("Profile")
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.secondary)
        .textCase(.uppercase)
        .padding(.horizontal, DS.Spacing.xs)

      VStack(spacing: 0) {
        // User Info Header
        profileHeader

        Divider()

        // User Type Picker
        userTypePicker

        Divider()

        // Sign Out Button
        signOutButton
      }
      .background(DS.Colors.Background.card)
      .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusCard))
    }
    .confirmationDialog(
      "Change Role",
      isPresented: $showingTypeChangeConfirmation,
      titleVisibility: .visible
    ) {
      Button("Change to \(pendingUserType?.displayName ?? "")") {
        confirmTypeChange()
      }
      Button("Cancel", role: .cancel) {
        pendingUserType = nil
      }
    } message: {
      Text("Are you sure you want to change your role to \(pendingUserType?.displayName ?? "")? This will affect which features you can access.")
    }
    .confirmationDialog(
      "Sign Out",
      isPresented: $showingLogoutConfirmation,
      titleVisibility: .visible
    ) {
      Button("Sign Out", role: .destructive) {
        Task {
          await authManager.signOut()
        }
      }
      Button("Cancel", role: .cancel) { }
    } message: {
      Text("Are you sure you want to sign out?")
    }
    .alert(
      "Update Failed",
      isPresented: Binding(
        get: { updateError != nil },
        set: { if !$0 { updateError = nil } }
      )
    ) {
      Button("OK") {
        updateError = nil
      }
    } message: {
      Text(updateError?.localizedDescription ?? "An unknown error occurred.")
    }
  }

  // MARK: - Subviews

  private var profileHeader: some View {
    HStack(spacing: DS.Spacing.md) {
      UserAvatar(user: currentUser, size: .large)

      VStack(alignment: .leading, spacing: 2) {
        Text(currentUser?.name ?? "Unknown")
          .font(DS.Typography.headline)
          .foregroundStyle(DS.Colors.Text.primary)

        Text(currentUser?.email ?? "")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.secondary)
      }

      Spacer()
    }
    .padding(DS.Spacing.md)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Profile: \(currentUser?.name ?? "Unknown"), \(currentUser?.email ?? "")")
  }

  private var userTypePicker: some View {
    HStack {
      Label("Role", systemImage: DS.Icons.Entity.user)
        .font(DS.Typography.body)
        .foregroundStyle(DS.Colors.Text.primary)

      Spacer()

      if isUpdatingType {
        ProgressView()
          .controlSize(.small)
          .accessibilityLabel("Updating role")
      } else {
        Menu {
          ForEach(UserType.allCases, id: \.self) { type in
            Button {
              requestTypeChange(to: type)
            } label: {
              HStack {
                Text(type.displayName)
                if type == currentUser?.userType {
                  Image(systemName: "checkmark")
                }
              }
            }
          }
        } label: {
          HStack(spacing: DS.Spacing.xs) {
            Text(currentUser?.userType.displayName ?? "Unknown")
              .font(DS.Typography.body)
              .foregroundStyle(DS.Colors.Text.secondary)
            Image(systemName: "chevron.up.chevron.down")
              .font(.system(size: 12))
              .foregroundStyle(DS.Colors.Text.tertiary)
          }
        }
        .accessibilityLabel("Role: \(currentUser?.userType.displayName ?? "Unknown")")
        .accessibilityHint("Tap to change your role")
      }
    }
    .padding(DS.Spacing.md)
    .frame(minHeight: DS.Spacing.minTouchTarget)
  }

  private var signOutButton: some View {
    Button {
      showingLogoutConfirmation = true
    } label: {
      HStack {
        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
          .font(DS.Typography.body)
          .foregroundStyle(DS.Colors.destructive)
        Spacer()
      }
      .padding(DS.Spacing.md)
      .frame(minHeight: DS.Spacing.minTouchTarget)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Sign out of your account")
    .accessibilityHint("You will need to sign in again")
  }

  // MARK: - Actions

  private func requestTypeChange(to newType: UserType) {
    guard newType != currentUser?.userType else { return }
    pendingUserType = newType
    showingTypeChangeConfirmation = true
  }

  private func confirmTypeChange() {
    guard let newType = pendingUserType else { return }
    pendingUserType = nil

    isUpdatingType = true
    Task {
      do {
        try await syncManager.updateUserType(newType)
      } catch {
        updateError = error
      }
      isUpdatingType = false
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
