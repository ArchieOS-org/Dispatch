//
//  ToolbarIconButton.swift
//  Dispatch
//
//  Things 3-style icon button for macOS bottom toolbar
//  Created by Claude on 2025-12-25.
//

#if os(macOS)
import SwiftUI

/// A 36pt icon-only button for the macOS bottom toolbar.
/// Follows Things 3 styling: icon-only, no labels, tooltip on hover.
struct ToolbarIconButton: View {

  // MARK: Internal

  let icon: String
  let action: () -> Void
  let accessibilityLabel: String
  var isDestructive = false

  var body: some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: DS.Spacing.bottomToolbarIconSize, weight: .medium))
        .foregroundStyle(iconColor)
        .frame(
          width: DS.Spacing.bottomToolbarButtonSize,
          height: DS.Spacing.bottomToolbarButtonSize
        )
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
    .help(accessibilityLabel)
  }

  // MARK: Private

  private var iconColor: Color {
    if isDestructive {
      .red.opacity(0.7)
    } else {
      .primary.opacity(0.6)
    }
  }
}

#Preview {
  HStack(spacing: DS.Spacing.sm) {
    ToolbarIconButton(
      icon: "plus",
      action: { },
      accessibilityLabel: "New item"
    )
    ToolbarIconButton(
      icon: "magnifyingglass",
      action: { },
      accessibilityLabel: "Search"
    )
    ToolbarIconButton(
      icon: "trash",
      action: { },
      accessibilityLabel: "Delete",
      isDestructive: true
    )
  }
  .padding()
  .background(Color(nsColor: .windowBackgroundColor))
}
#endif
