//
//  MacBottomToolbar.swift
//  Dispatch
//
//  Bottom toolbar for macOS with Add, Filter, and Search buttons.
//  Buttons use simple hover backgrounds (no glass effect) to match the top toolbar style.
//

#if os(macOS)
import SwiftUI

/// Bottom toolbar for macOS containing Add, Filter (grouped left), and Search (right).
/// Buttons use simple hover backgrounds to match the native top toolbar button style.
struct MacBottomToolbar: View {

  // MARK: Internal

  @Binding var audience: AudienceLens
  let onAdd: () -> Void
  let onSearch: () -> Void

  var body: some View {
    HStack(spacing: 0) {
      // Left group: Add button + Filter menu
      leftButtonGroup

      Spacer()

      // Right: Search button
      searchButton
    }
    .padding(.horizontal, DS.Spacing.bottomToolbarPadding)
    .padding(.bottom, DS.Spacing.lg)
    .frame(height: DS.Spacing.bottomToolbarHeight + DS.Spacing.lg)
  }

  // MARK: Private

  @ScaledMetric(relativeTo: .headline)
  private var iconSize: CGFloat = DS.Spacing.bottomToolbarIconSize

  @State private var isAddHovering = false
  @State private var isSearchHovering = false

  @ViewBuilder
  private var leftButtonGroup: some View {
    HStack(spacing: 0) {
      // Add button
      Button(action: onAdd) {
        Image(systemName: "plus")
          .font(.system(size: iconSize, weight: .medium))
          .foregroundStyle(.primary)
          .frame(
            width: DS.Spacing.bottomToolbarButtonSize,
            height: DS.Spacing.bottomToolbarButtonSize
          )
          .background {
            RoundedRectangle(cornerRadius: DS.Radius.small)
              .fill(isAddHovering ? Color.primary.opacity(0.08) : Color.clear)
          }
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .onHover { isAddHovering = $0 }
      .help("New Item")
      .keyboardShortcut("n", modifiers: .command)
      .accessibilityLabel("New item")
      .accessibilityHint("Creates a new task, activity, or listing based on current context")

      // Filter menu
      FilterMenu(audience: $audience)
    }
    .padding(.horizontal, DS.Spacing.xs)
  }

  @ViewBuilder
  private var searchButton: some View {
    Button(action: onSearch) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: iconSize, weight: .medium))
        .foregroundStyle(.primary)
        .frame(
          width: DS.Spacing.bottomToolbarButtonSize,
          height: DS.Spacing.bottomToolbarButtonSize
        )
        .background {
          RoundedRectangle(cornerRadius: DS.Radius.small)
            .fill(isSearchHovering ? Color.primary.opacity(0.08) : Color.red)
        }
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isSearchHovering = $0 }
    .help("Search")
    .keyboardShortcut("f", modifiers: .command)
    .accessibilityLabel("Search")
    .accessibilityHint("Opens global search overlay")
    .padding(.horizontal, DS.Spacing.xs)
  }
}

// MARK: - Previews

#Preview("Mac Bottom Toolbar - Default") {
  ZStack(alignment: .bottom) {
    DS.Colors.Background.primary.ignoresSafeArea()

    MacBottomToolbar(
      audience: .constant(.all),
      onAdd: { },
      onSearch: { }
    )
  }
  .frame(width: 600, height: 350)
}

#Preview("Mac Bottom Toolbar - Admin Filter") {
  ZStack(alignment: .bottom) {
    DS.Colors.Background.primary.ignoresSafeArea()

    MacBottomToolbar(
      audience: .constant(.admin),
      onAdd: { },
      onSearch: { }
    )
  }
  .frame(width: 600, height: 350)
}

#Preview("Mac Bottom Toolbar - Marketing Filter") {
  ZStack(alignment: .bottom) {
    DS.Colors.Background.primary.ignoresSafeArea()

    MacBottomToolbar(
      audience: .constant(.marketing),
      onAdd: { },
      onSearch: { }
    )
  }
  .frame(width: 600, height: 350)
}

#Preview("Mac Bottom Toolbar - Dark Mode") {
  ZStack(alignment: .bottom) {
    DS.Colors.Background.primary.ignoresSafeArea()

    MacBottomToolbar(
      audience: .constant(.admin),
      onAdd: { },
      onSearch: { }
    )
  }
  .frame(width: 600, height: 350)
  .preferredColorScheme(.dark)
}
#endif
