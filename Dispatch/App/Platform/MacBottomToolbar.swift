//
//  MacBottomToolbar.swift
//  Dispatch
//
//  Bottom toolbar for macOS with Add, Filter, and Search buttons.
//  Uses native SwiftUI patterns and matches the existing top toolbar style.
//

#if os(macOS)
import SwiftUI

/// Bottom toolbar for macOS containing Add, Filter (grouped left), and Search (right).
/// Uses `.thinMaterial` background to match the existing top toolbar aesthetic.
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
    .frame(height: DS.Spacing.bottomToolbarHeight)
    .background(.thinMaterial)
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
          .foregroundStyle(.primary.opacity(0.6))
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
  }

  @ViewBuilder
  private var searchButton: some View {
    Button(action: onSearch) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: iconSize, weight: .medium))
        .foregroundStyle(.primary.opacity(0.6))
        .frame(
          width: DS.Spacing.bottomToolbarButtonSize,
          height: DS.Spacing.bottomToolbarButtonSize
        )
        .background {
          RoundedRectangle(cornerRadius: DS.Radius.small)
            .fill(isSearchHovering ? Color.primary.opacity(0.08) : Color.clear)
        }
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isSearchHovering = $0 }
    .help("Search")
    .keyboardShortcut("f", modifiers: .command)
    .accessibilityLabel("Search")
    .accessibilityHint("Opens global search overlay")
  }
}

// MARK: - Previews

#Preview("Mac Bottom Toolbar - Default") {
  VStack(spacing: 0) {
    Color.gray.opacity(0.1)
      .frame(height: 300)

    MacBottomToolbar(
      audience: .constant(.all),
      onAdd: { },
      onSearch: { }
    )
  }
  .frame(width: 600)
}

#Preview("Mac Bottom Toolbar - Admin Filter") {
  VStack(spacing: 0) {
    Color.gray.opacity(0.1)
      .frame(height: 300)

    MacBottomToolbar(
      audience: .constant(.admin),
      onAdd: { },
      onSearch: { }
    )
  }
  .frame(width: 600)
}

#Preview("Mac Bottom Toolbar - Marketing Filter") {
  VStack(spacing: 0) {
    Color.gray.opacity(0.1)
      .frame(height: 300)

    MacBottomToolbar(
      audience: .constant(.marketing),
      onAdd: { },
      onSearch: { }
    )
  }
  .frame(width: 600)
}

#Preview("Mac Bottom Toolbar - Dark Mode") {
  VStack(spacing: 0) {
    Color.gray.opacity(0.1)
      .frame(height: 300)

    MacBottomToolbar(
      audience: .constant(.admin),
      onAdd: { },
      onSearch: { }
    )
  }
  .frame(width: 600)
  .preferredColorScheme(.dark)
}
#endif
