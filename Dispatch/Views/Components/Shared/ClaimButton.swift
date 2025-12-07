//
//  ClaimButton.swift
//  Dispatch
//
//  Shared Component - State-dependent claim/release button
//  Created by Claude on 2025-12-06.
//

import SwiftUI

/// A button that allows users to claim or release work items.
/// Displays different states based on claim ownership:
/// - Unclaimed: "Claim" button (primary)
/// - Claimed by me: "Release" button with confirmation
/// - Claimed by other: Disabled, shows claimer name
struct ClaimButton: View {
    let claimState: ClaimState
    var onClaim: () -> Void = {}
    var onRelease: () -> Void = {}

    @State private var showReleaseConfirmation = false

    var body: some View {
        Group {
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
                    Button("Cancel", role: .cancel) {}
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    private var accessibilityLabel: String {
        switch claimState {
        case .unclaimed:
            return "Unclaimed item"
        case .claimedByMe:
            return "Claimed by you"
        case .claimedByOther(let user):
            return "Claimed by \(user.name)"
        }
    }

    private var accessibilityHint: String {
        switch claimState {
        case .unclaimed:
            return "Double tap to claim this item"
        case .claimedByMe:
            return "Double tap to release this item"
        case .claimedByOther:
            return "This item is not available to claim"
        }
    }
}

// MARK: - Preview

#Preview("Claim Button States") {
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
