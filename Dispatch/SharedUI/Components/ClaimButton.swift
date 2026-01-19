//
//  ClaimButton.swift
//  Dispatch
//
//  A tappable icon button for claiming work items.
//  Tap/click to claim for self, long-press/right-click for assignment menu.
//

import DesignSystem
import SwiftUI

/// State representing who owns a work item
enum ClaimState {
  /// No one is assigned - available to claim
  case available

  /// Current user has claimed this item
  case claimedBySelf

  /// Another user has claimed this item
  case claimedByOther(name: String)
}

/// A tappable icon button for claiming work items.
///
/// Interaction patterns:
/// - iOS: Tap to claim, long-press for assignment menu
/// - macOS: Click to claim, right-click (contextMenu) for assignment menu
///
/// Touch target is at least 44pt per Apple HIG.
struct ClaimButton: View {

  // MARK: Lifecycle

  init(
    state: ClaimState = .available,
    onClaim: @escaping () -> Void,
    onAssign: @escaping () -> Void
  ) {
    self.state = state
    self.onClaim = onClaim
    self.onAssign = onAssign
  }

  // MARK: Internal

  /// Current claim state of the work item
  let state: ClaimState

  /// Action to perform when user wants to claim for themselves
  let onClaim: () -> Void

  /// Action to perform when user wants to open assignment menu/sheet
  let onAssign: () -> Void

  var body: some View {
    Button {
      handleTap()
    } label: {
      iconView
    }
    .buttonStyle(.plain)
    .frame(minWidth: DS.Spacing.minTouchTarget, minHeight: DS.Spacing.minTouchTarget)
    .contentShape(Rectangle())
    .contextMenu {
      contextMenuContent
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint(accessibilityHint)
    .accessibilityAddTraits(.isButton)
  }

  // MARK: Private

  private var iconName: String {
    switch state {
    case .available:
      DS.Icons.Claim.unclaimed
    case .claimedBySelf:
      DS.Icons.Claim.claimed
    case .claimedByOther:
      DS.Icons.Claim.claimedByOther
    }
  }

  private var iconColor: Color {
    switch state {
    case .available:
      DS.Colors.Claim.unclaimed
    case .claimedBySelf:
      DS.Colors.Claim.claimedByMe
    case .claimedByOther:
      DS.Colors.Claim.claimedByOther
    }
  }

  private var iconView: some View {
    Image(systemName: iconName)
      .font(.system(size: 16, weight: .medium))
      .foregroundStyle(iconColor)
  }

  @ViewBuilder
  private var contextMenuContent: some View {
    switch state {
    case .available:
      Button {
        onClaim()
      } label: {
        Label("Claim for Myself", systemImage: DS.Icons.Claim.claimed)
      }

      Button {
        onAssign()
      } label: {
        Label("Assign to...", systemImage: DS.Icons.Entity.team)
      }

    case .claimedBySelf:
      Button {
        onAssign()
      } label: {
        Label("Reassign...", systemImage: DS.Icons.Entity.team)
      }

      Button(role: .destructive) {
        onClaim() // Release is handled by parent via onClaim
      } label: {
        Label("Release Claim", systemImage: DS.Icons.Claim.release)
      }

    case .claimedByOther(let name):
      Text("Claimed by \(name)")

      Button {
        onAssign()
      } label: {
        Label("Reassign...", systemImage: DS.Icons.Entity.team)
      }
    }
  }

  private var accessibilityLabel: String {
    switch state {
    case .available:
      "Available to claim"
    case .claimedBySelf:
      "Claimed by you"
    case .claimedByOther(let name):
      "Claimed by \(name)"
    }
  }

  private var accessibilityHint: String {
    switch state {
    case .available:
      "Tap to claim, hold for options"
    case .claimedBySelf:
      "Tap to reassign, hold for options"
    case .claimedByOther:
      "Tap to reassign, hold for options"
    }
  }

  private func handleTap() {
    switch state {
    case .available:
      // Tap claims for self
      onClaim()
    case .claimedBySelf, .claimedByOther:
      // Tap opens assignment options when already claimed
      onAssign()
    }
  }
}

// MARK: - Preview

#Preview("ClaimButton - States") {
  VStack(spacing: DS.Spacing.xl) {
    Group {
      Text("Available")
        .font(DS.Typography.caption)
      ClaimButton(
        state: .available,
        onClaim: { },
        onAssign: { }
      )
    }

    Divider()

    Group {
      Text("Claimed by Self")
        .font(DS.Typography.caption)
      ClaimButton(
        state: .claimedBySelf,
        onClaim: { },
        onAssign: { }
      )
    }

    Divider()

    Group {
      Text("Claimed by Other")
        .font(DS.Typography.caption)
      ClaimButton(
        state: .claimedByOther(name: "Alice Smith"),
        onClaim: { },
        onAssign: { }
      )
    }

    Divider()

    Group {
      Text("In Context (Row)")
        .font(DS.Typography.caption)
      HStack {
        Text("Some Task Title")
          .font(DS.Typography.body)
        Spacer()
        ClaimButton(
          state: .available,
          onClaim: { },
          onAssign: { }
        )
      }
      .padding(DS.Spacing.cardPadding)
      .background(DS.Colors.Background.card)
      .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium))
    }
  }
  .padding()
}
