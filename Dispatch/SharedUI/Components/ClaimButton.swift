//
//  ClaimButton.swift
//  Dispatch
//
//  Shared Component - State-dependent claim/release button
//  Created by Claude on 2025-12-06.
//

import SwiftUI

// MARK: - ClaimButtonStyle

/// Display style for ClaimButton
enum ClaimButtonStyle {
  /// Full display: label + icon + confirmation dialog for release
  case full
  /// Compact display: icon-only for list rows, no confirmation dialog
  case compact
}

// MARK: - ClaimButton

/// A button that allows users to claim or release work items.
/// Displays different states based on claim ownership:
/// - Unclaimed: "Claim" button (primary)
/// - Claimed by me: "Release" button with confirmation (full) or direct release (compact)
/// - Claimed by other: Disabled, shows claimer name (full) or avatar only (compact)
struct ClaimButton: View {

  // MARK: Internal

  let claimState: ClaimState
  var style = ClaimButtonStyle.full
  var onClaim: () -> Void = { }
  var onRelease: () -> Void = { }

  var body: some View {
    Group {
      switch style {
      case .full:
        fullStyleBody
      case .compact:
        compactStyleBody
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint(accessibilityHint)
  }

  // MARK: Private

  @State private var showReleaseConfirmation = false

  private var accessibilityLabel: String {
    switch claimState {
    case .unclaimed:
      "Unclaimed item"
    case .claimedByMe:
      "Claimed by you"
    case .claimedByOther(let user):
      "Claimed by \(user.name)"
    }
  }

  private var accessibilityHint: String {
    switch claimState {
    case .unclaimed:
      "Double tap to claim this item"
    case .claimedByMe:
      "Double tap to release this item"
    case .claimedByOther:
      "This item is not available to claim"
    }
  }

  @ViewBuilder
  private var fullStyleBody: some View {
    switch claimState {
    case .unclaimed:
      Button(action: onClaim) {
        Label("Claim", systemImage: DS.Icons.Claim.unclaimed)
          .font(DS.Typography.bodySecondary)
      }
      .buttonStyle(.borderedProminent)
      .tint(DS.Colors.accent)

    case .claimedByMe:
      Button(action: { showReleaseConfirmation = true }) {
        Label("Release", systemImage: DS.Icons.Claim.release)
          .font(DS.Typography.bodySecondary)
      }
      .buttonStyle(.bordered)
      .confirmationDialog(
        "Release this item?",
        isPresented: $showReleaseConfirmation,
        titleVisibility: .visible
      ) {
        Button("Release", role: .destructive, action: onRelease)
        Button("Cancel", role: .cancel) { }
      } message: {
        Text("This will allow others to claim and work on this item.")
      }

    case .claimedByOther(let user):
      HStack(spacing: DS.Spacing.xs) {
        UserAvatar(user: user, size: .small)
        Text("Claimed by \(user.name)")
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Text.secondary)
      }
      .padding(.horizontal, DS.Spacing.sm)
      .padding(.vertical, DS.Spacing.xs)
      .background(DS.Colors.Background.secondary)
      .cornerRadius(DS.Spacing.radiusSmall)
    }
  }

  @ViewBuilder
  private var compactStyleBody: some View {
    switch claimState {
    case .unclaimed:
      Button(action: onClaim) {
        Image(systemName: DS.Icons.Claim.unclaimed)
          .font(.system(size: 16))
      }
      .buttonStyle(.borderless)
      .foregroundColor(DS.Colors.accent)

    case .claimedByMe:
      Button(action: onRelease) {
        Image(systemName: DS.Icons.Claim.release)
          .font(.system(size: 16))
      }
      .buttonStyle(.borderless)
      .foregroundColor(DS.Colors.Text.secondary)

    case .claimedByOther(let user):
      UserAvatar(user: user, size: .small)
    }
  }

}

// MARK: - Preview

#Preview("Claim Button States - Full") {
  VStack(spacing: DS.Spacing.lg) {
    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
      Text("Unclaimed").font(DS.Typography.caption)
      ClaimButton(claimState: .unclaimed)
    }

    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
      Text("Claimed by Me").font(DS.Typography.caption)
      ClaimButton(claimState: .claimedByMe(user: User(
        name: "Current User",
        email: "me@example.com",
        userType: .admin
      )))
    }

    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
      Text("Claimed by Other").font(DS.Typography.caption)
      ClaimButton(claimState: .claimedByOther(user: User(
        name: "Jane Smith",
        email: "jane@example.com",
        userType: .admin
      )))
    }
  }
  .padding()
}

#Preview("Claim Button States - Compact") {
  VStack(spacing: DS.Spacing.lg) {
    HStack(spacing: DS.Spacing.md) {
      Text("Unclaimed").font(DS.Typography.caption).frame(width: 100, alignment: .leading)
      ClaimButton(claimState: .unclaimed, style: .compact)
    }

    HStack(spacing: DS.Spacing.md) {
      Text("Claimed by Me").font(DS.Typography.caption).frame(width: 100, alignment: .leading)
      ClaimButton(
        claimState: .claimedByMe(user: User(
          name: "Current User",
          email: "me@example.com",
          userType: .admin
        )),
        style: .compact
      )
    }

    HStack(spacing: DS.Spacing.md) {
      Text("Claimed by Other").font(DS.Typography.caption).frame(width: 100, alignment: .leading)
      ClaimButton(
        claimState: .claimedByOther(user: User(
          name: "Jane Smith",
          email: "jane@example.com",
          userType: .admin
        )),
        style: .compact
      )
    }
  }
  .padding()
}
