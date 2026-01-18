//
//  ProfilePageView.swift
//  Dispatch
//
//  Profile management screen (navigable from Settings).
//  Allows users to view profile info, change role, and sign out.
//

import SwiftUI

// MARK: - ProfilePageView

/// Full profile management page accessible via navigation from Settings.
struct ProfilePageView: View {

  // MARK: Internal

  var body: some View {
    ZStack {
      StandardScreen(title: "Profile", layout: .column, scroll: .automatic) {
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
        .padding(.vertical, DS.Spacing.sm)
      }
      .environment(\.pullToSearchDisabled, true)

      // iOS/iPadOS: Custom fullscreen role change modal
      #if os(iOS)
      if showingTypeChangeModal, let newType = pendingUserType {
        RoleChangeModal(
          newType: newType,
          onConfirm: {
            confirmTypeChange()
          },
          onCancel: {
            pendingUserType = nil
            showingTypeChangeModal = false
          }
        )
      }
      #endif
    }
    // macOS: Use native confirmation dialog (looks good on desktop)
    #if os(macOS)
    .confirmationDialog(
      "Change Role",
      isPresented: $showingTypeChangeModal,
      titleVisibility: .visible
    ) {
      Button("Change to \(pendingUserType?.displayName ?? "")") {
        confirmTypeChange()
      }
      Button("Cancel", role: .cancel) {
        pendingUserType = nil
      }
    } message: {
      Text(
        "Are you sure you want to change your role to \(pendingUserType?.displayName ?? "")? This will affect which features you can access."
      )
    }
    #endif
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

  // MARK: Private

  /// Scaled chevron icon size for Dynamic Type support (base: 12pt)
  @ScaledMetric(relativeTo: .caption)
  private var chevronIconSize: CGFloat = 12

  @EnvironmentObject private var authManager: AuthManager
  @EnvironmentObject private var syncManager: SyncManager

  @State private var showingLogoutConfirmation = false
  @State private var showingTypeChangeModal = false
  @State private var pendingUserType: UserType?
  @State private var isUpdatingType = false
  @State private var updateError: Error?

  private var currentUser: User? {
    syncManager.currentUser
  }

  // MARK: - Subviews

  private var profileHeader: some View {
    HStack(spacing: DS.Spacing.md) {
      UserAvatar(user: currentUser, size: .large)

      VStack(alignment: .leading, spacing: 2) {
        Text(currentUser?.name ?? "Unknown")
          .font(DS.Typography.headline)
          .foregroundStyle(DS.Colors.Text.primary)
          .lineLimit(1)

        Text(currentUser?.email ?? "")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.secondary)
          .lineLimit(1)
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
            #if os(iOS)
            Image(systemName: "chevron.up.chevron.down")
              .font(.system(size: chevronIconSize))
              .foregroundStyle(DS.Colors.Text.tertiary)
            #endif
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

  private func requestTypeChange(to newType: UserType) {
    guard newType != currentUser?.userType else { return }
    pendingUserType = newType
    showingTypeChangeModal = true
  }

  private func confirmTypeChange() {
    guard let newType = pendingUserType else { return }
    pendingUserType = nil
    showingTypeChangeModal = false

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

// MARK: - RoleChangeModal

#if os(iOS)
/// Custom fullscreen modal for role change confirmation on iOS/iPadOS.
/// Shows centered card on dimmed backdrop with tap-to-dismiss.
private struct RoleChangeModal: View {

  // MARK: Internal

  let newType: UserType
  let onConfirm: () -> Void
  let onCancel: () -> Void

  var body: some View {
    ZStack {
      // Scrim backdrop - tap to dismiss (hidden from VoiceOver; Cancel button provides accessible dismiss)
      DS.Colors.modalScrim
        .ignoresSafeArea()
        .onTapGesture {
          dismissWithAnimation()
        }
        .accessibilityHidden(true)

      // Centered modal card
      VStack(spacing: DS.Spacing.lg) {
        // Header
        VStack(spacing: DS.Spacing.xs) {
          Text("Change Role")
            .font(DS.Typography.headline)
            .foregroundStyle(DS.Colors.Text.primary)

          Text("Are you sure you want to change your role to \(newType.displayName)?")
            .font(DS.Typography.body)
            .foregroundStyle(DS.Colors.Text.secondary)
            .multilineTextAlignment(.center)
        }

        Text("This will affect which features you can access.")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.tertiary)
          .multilineTextAlignment(.center)

        // Buttons
        VStack(spacing: DS.Spacing.sm) {
          Button {
            dismissWithAnimation {
              onConfirm()
            }
          } label: {
            Text("Change to \(newType.displayName)")
              .font(DS.Typography.body.weight(.semibold))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .frame(height: DS.Spacing.minTouchTarget)
              .background(DS.Colors.accent)
              .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium))
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Change to \(newType.displayName)")
          .accessibilityHint("Confirms role change")

          Button {
            dismissWithAnimation()
          } label: {
            Text("Cancel")
              .font(DS.Typography.body)
              .foregroundStyle(DS.Colors.Text.secondary)
              .frame(maxWidth: .infinity)
              .frame(height: DS.Spacing.minTouchTarget)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Cancel")
          .accessibilityHint("Dismisses without changing role")
        }
      }
      .padding(DS.Spacing.xl)
      .frame(maxWidth: 320)
      .background(DS.Colors.Background.groupedSecondary)
      .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusLarge))
      .dsShadow(DS.Shadows.elevated)
      .scaleEffect(isAppearing ? 1 : 0.9)
      .opacity(isAppearing ? 1 : 0)
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isAppearing)
    .onAppear {
      isAppearing = true
    }
    .accessibilityElement(children: .contain)
    .accessibilityAddTraits(.isModal)
  }

  // MARK: Private

  @State private var isAppearing = false

  private func dismissWithAnimation(completion: (() -> Void)? = nil) {
    withAnimation(.easeOut(duration: 0.2)) {
      isAppearing = false
    }
    // Use Task for delay - proper SwiftUI pattern for post-animation work
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(200))
      if let completion {
        completion()
      } else {
        onCancel()
      }
    }
  }
}
#endif

// MARK: - Preview

#Preview {
  PreviewShell { _ in
    // Seed with a sample user
  } content: { _ in
    NavigationStack {
      ProfilePageView()
    }
  }
}
