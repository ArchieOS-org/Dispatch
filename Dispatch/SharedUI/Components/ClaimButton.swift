//
//  ClaimButton.swift
//  Dispatch
//
//  A tappable icon button for claiming unassigned work items.
//  Tap/click to claim for self, long-press/right-click for assignment menu.
//

import DesignSystem
import SwiftUI

// MARK: - ClaimButton

/// A tappable icon button for claiming unassigned work items.
///
/// This button is displayed when a work item has no assignees. When users are assigned,
/// `OverlappingAvatars` shows user avatars instead of this button.
///
/// Interaction patterns:
/// - iOS: Tap to claim, long-press for assignment menu
/// - macOS: Click to claim, right-click (contextMenu) for assignment menu
///
/// Touch target is at least 44pt per Apple HIG.
struct ClaimButton: View {

  // MARK: Lifecycle

  init(
    onClaim: @escaping () -> Void,
    onAssign: (() -> Void)? = nil
  ) {
    self.onClaim = onClaim
    self.onAssign = onAssign
  }

  // MARK: Internal

  /// Action to perform when user wants to claim for themselves
  let onClaim: () -> Void

  /// Action to perform when user wants to open assignment menu/sheet (nil hides menu item)
  let onAssign: (() -> Void)?

  var body: some View {
    Button {
      onClaim()
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
    .accessibilityLabel(Text("Available to claim"))
    .accessibilityHint(Text("Tap to claim, hold for options"))
    .accessibilityAddTraits(.isButton)
  }

  // MARK: Private

  private var iconView: some View {
    Image(systemName: DS.Icons.Claim.unclaimed)
      .font(.system(size: 16, weight: .medium))
      .foregroundStyle(DS.Colors.Claim.unclaimed)
  }

  @ViewBuilder
  private var contextMenuContent: some View {
    Button {
      onClaim()
    } label: {
      Label("Claim for Myself", systemImage: DS.Icons.Claim.claimed)
    }

    if let onAssign {
      Button {
        onAssign()
      } label: {
        Label("Assign to...", systemImage: DS.Icons.Entity.team)
      }
    }
  }
}

// MARK: - Preview

#Preview("ClaimButton") {
  VStack(spacing: DS.Spacing.xl) {
    // Section 1: Standalone
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      Text("Standalone")
        .font(DS.Typography.caption)
        .foregroundStyle(.secondary)

      ClaimButton(onClaim: { }, onAssign: { })
    }

    Divider()

    // Section 2: In Row Context
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      Text("In Row Context")
        .font(DS.Typography.caption)
        .foregroundStyle(.secondary)

      HStack {
        Text("Review offer documents")
          .font(DS.Typography.body)
        Spacer()
        ClaimButton(onClaim: { }, onAssign: { })
      }
      .padding(DS.Spacing.cardPadding)
      .background(DS.Colors.Background.card)
      .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium))
    }

    Divider()

    // Section 3: Multiple Rows
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      Text("Multiple Rows")
        .font(DS.Typography.caption)
        .foregroundStyle(.secondary)

      VStack(spacing: DS.Spacing.xs) {
        ForEach(["Schedule showing", "Send disclosure", "Order inspection"], id: \.self) { task in
          HStack {
            Text(task)
              .font(DS.Typography.body)
            Spacer()
            ClaimButton(onClaim: { }, onAssign: { })
          }
          .padding(DS.Spacing.cardPadding)
          .background(DS.Colors.Background.card)
          .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium))
        }
      }
    }
  }
  .padding()
}
