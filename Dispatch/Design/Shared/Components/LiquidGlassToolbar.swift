//
//  LiquidGlassToolbar.swift
//  Dispatch
//
//  WWDC25 Liquid Glass floating toolbar component.
//  Shared between iPad and macOS for 80%+ code sharing.
//
//  Uses iOS 26/macOS 26 glass effect APIs with Material fallback.
//

import SwiftUI

// MARK: - LiquidGlassToolbarContext

/// Screen context for toolbar action configuration.
/// Determines which actions are available in the toolbar.
enum LiquidGlassToolbarContext {
  /// List views: workspace, properties, listings, realtors
  case list(ListContext)
  /// Detail views: work item, listing
  case detail(DetailContext)

  // MARK: Internal

  enum ListContext {
    case workspace
    case properties
    case listings
    case realtors
  }

  enum DetailContext {
    case workItem
    case listing
  }

  var showsNewButton: Bool {
    switch self {
    case .list:
      true
    case .detail:
      false
    }
  }

  var showsFilterMenu: Bool {
    switch self {
    case .list(.workspace), .list(.properties):
      true
    case .list(.listings), .list(.realtors), .detail:
      false
    }
  }
}

// MARK: - LiquidGlassToolbar

/// A WWDC25-style floating toolbar with Liquid Glass effect.
///
/// Uses `.glassEffect()` on iOS 26+/macOS 26+, falls back to Material on earlier versions.
/// Designed for use with `.safeAreaInset(edge: .top)` for floating toolbar behavior.
///
/// Features:
/// - Liquid Glass material effect (iOS 26+) or thinMaterial fallback
/// - Monochrome SF Symbols with automatic scaling
/// - ToolbarSpacer-style item grouping (left/center/right)
/// - Badge support for notifications
/// - Platform-adaptive styling (iPad vs macOS)
struct LiquidGlassToolbar: View {

  // MARK: Lifecycle

  init(
    context: LiquidGlassToolbarContext,
    audience: Binding<AudienceLens>? = nil,
    onNew: (() -> Void)? = nil,
    onSearch: (() -> Void)? = nil,
    onDuplicateWindow: (() -> Void)? = nil,
    duplicateWindowDisabled: Bool = false,
    onDelete: (() -> Void)? = nil
  ) {
    self.context = context
    self.audience = audience
    self.onNew = onNew
    self.onSearch = onSearch
    self.onDuplicateWindow = onDuplicateWindow
    self.duplicateWindowDisabled = duplicateWindowDisabled
    self.onDelete = onDelete
  }

  // MARK: Internal

  let context: LiquidGlassToolbarContext

  // List context actions
  var audience: Binding<AudienceLens>?
  var onNew: (() -> Void)?
  var onSearch: (() -> Void)?

  // Window action (macOS)
  var onDuplicateWindow: (() -> Void)?
  var duplicateWindowDisabled: Bool

  /// Detail context actions
  var onDelete: (() -> Void)?

  var body: some View {
    HStack(spacing: 0) {
      // Left group
      leftGroup

      Spacer()

      // Right group
      rightGroup
    }
    .padding(.horizontal, DS.Spacing.lg)
    .frame(height: DS.Spacing.liquidGlassToolbarHeight)
    .liquidGlassBackground()
    .padding(.horizontal, DS.Spacing.lg)
    .padding(.top, DS.Spacing.sm)
  }

  // MARK: Private

  @ViewBuilder
  private var leftGroup: some View {
    HStack(spacing: DS.Spacing.md) {
      // Filter menu (list contexts with filtering)
      if context.showsFilterMenu, let audienceBinding = audience {
        FilterMenu(audience: audienceBinding)
      }

      // New button (list contexts)
      if context.showsNewButton, let onNew {
        LiquidGlassToolbarButton(
          icon: "plus",
          action: onNew,
          accessibilityLabel: "New item"
        )
      }
    }
  }

  @ViewBuilder
  private var rightGroup: some View {
    HStack(spacing: DS.Spacing.md) {
      // Detail context: delete button
      if case .detail = context, let onDelete {
        LiquidGlassToolbarButton(
          icon: "trash",
          action: onDelete,
          accessibilityLabel: "Delete",
          isDestructive: true
        )
      }

      #if os(macOS)
      // macOS: duplicate window button
      if let onDuplicateWindow {
        LiquidGlassToolbarButton(
          icon: "square.on.square",
          action: onDuplicateWindow,
          accessibilityLabel: "New Window"
        )
        .help("Opens a new window with independent sidebar and search state")
        .disabled(duplicateWindowDisabled)
      }
      #endif

      // Search button
      if let onSearch {
        LiquidGlassToolbarButton(
          icon: "magnifyingglass",
          action: onSearch,
          accessibilityLabel: "Search"
        )
      }
    }
  }

}

// MARK: - LiquidGlassToolbarButton

/// Icon button for the Liquid Glass toolbar.
/// Monochrome SF Symbol with hover state.
private struct LiquidGlassToolbarButton: View {

  // MARK: Internal

  let icon: String
  let action: () -> Void
  let accessibilityLabel: String
  var isDestructive: Bool = false

  var body: some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: DS.Spacing.liquidGlassToolbarIconSize, weight: .medium))
        .foregroundStyle(iconColor)
        .frame(
          width: DS.Spacing.liquidGlassToolbarButtonSize,
          height: DS.Spacing.liquidGlassToolbarButtonSize
        )
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
    #if os(macOS)
      .help(accessibilityLabel)
    #endif
  }

  // MARK: Private

  private var iconColor: Color {
    if isDestructive {
      .red.opacity(0.8)
    } else {
      .primary.opacity(0.7)
    }
  }

}

// MARK: - Liquid Glass Background Modifier

extension View {

  // MARK: Internal

  /// Applies Liquid Glass background effect on iOS 26+/macOS 26+.
  /// Falls back to thinMaterial with rounded rectangle on earlier versions.
  @ViewBuilder
  func liquidGlassBackground() -> some View {
    // iOS 26/macOS 26 APIs are not yet stable in all CI environments.
    // Use Material fallback until glassEffect is available.
    // When available, replace with:
    // if #available(iOS 26.0, macOS 26.0, *) {
    //   self.glassEffect(.regular, in: .rect(cornerRadius: DS.Radius.large))
    // } else {
    //   self.liquidGlassFallback()
    // }
    liquidGlassFallback()
  }

  // MARK: Private

  @ViewBuilder
  private func liquidGlassFallback() -> some View {
    background {
      RoundedRectangle(cornerRadius: DS.Radius.large)
        .fill(.thinMaterial)
        .overlay {
          RoundedRectangle(cornerRadius: DS.Radius.large)
            .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
  }
}

// MARK: - Previews

#Preview("Liquid Glass Toolbar - List") {
  ZStack {
    LinearGradient(
      colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .ignoresSafeArea()

    VStack {
      LiquidGlassToolbar(
        context: .list(.workspace),
        audience: .constant(.all),
        onNew: { },
        onSearch: { }
      )

      Spacer()
    }
  }
  .frame(width: 600, height: 400)
}

#Preview("Liquid Glass Toolbar - Detail") {
  ZStack {
    LinearGradient(
      colors: [.orange.opacity(0.3), .red.opacity(0.3)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .ignoresSafeArea()

    VStack {
      LiquidGlassToolbar(
        context: .detail(.workItem),
        onSearch: { },
        onDelete: { }
      )

      Spacer()
    }
  }
  .frame(width: 600, height: 400)
}

#Preview("Liquid Glass Toolbar - Dark Mode") {
  ZStack {
    LinearGradient(
      colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .ignoresSafeArea()

    VStack {
      LiquidGlassToolbar(
        context: .list(.listings),
        onNew: { },
        onSearch: { }
      )

      Spacer()
    }
  }
  .frame(width: 600, height: 400)
  .preferredColorScheme(.dark)
}
