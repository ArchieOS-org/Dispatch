//
//  ToolbarIconButton.swift
//  Dispatch
//
//  Things 3-style icon button for macOS bottom toolbar
//  Created by Claude on 2025-12-25.
//

#if os(macOS)
import SwiftUI

/// A 36pt icon-only button with hover state for the macOS bottom toolbar.
/// Follows Things 3 styling: icon-only, no labels, subtle hover feedback.
struct ToolbarIconButton: View {
  let icon: String
  let action: () -> Void
  let accessibilityLabel: String
  var isDestructive: Bool = false

  @State private var isHovering = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .background(
          RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall)
            .fill(isHovering ? Color.primary.opacity(0.08) : Color.clear)
        )
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      isHovering = hovering
    }
    .animation(
      reduceMotion ? .none : .easeInOut(duration: 0.15),
      value: isHovering
    )
    .accessibilityLabel(accessibilityLabel)
  }

  private var iconColor: Color {
    if isDestructive {
      return isHovering ? .red : .red.opacity(0.7)
    } else {
      return isHovering ? .primary : .primary.opacity(0.6)
    }
  }
}

#Preview {
  HStack(spacing: DS.Spacing.sm) {
    ToolbarIconButton(
      icon: "plus",
      action: {},
      accessibilityLabel: "New item"
    )
    ToolbarIconButton(
      icon: "magnifyingglass",
      action: {},
      accessibilityLabel: "Search"
    )
    ToolbarIconButton(
      icon: "trash",
      action: {},
      accessibilityLabel: "Delete",
      isDestructive: true
    )
  }
  .padding()
  .background(Color(nsColor: .windowBackgroundColor))
}
#endif
