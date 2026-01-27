//
//  StandardScreen.swift
//  Dispatch
//
//  Created for Dispatch Architecture Unification
//

import SwiftUI

// MARK: - StandardScreenScrollMode

/// Scroll mode for contract enforcement in child components.
/// Used by StandardGroupedList to verify correct usage context.
enum StandardScreenScrollMode {
  case automatic // StandardScreen owns ScrollView
  case disabled // No ScrollView, child may own scrolling
}

// MARK: - StandardScreenScrollModeKey

private struct StandardScreenScrollModeKey: EnvironmentKey {
  static let defaultValue: StandardScreenScrollMode? = nil
}

extension EnvironmentValues {
  /// The scroll mode set by StandardScreen. Nil if outside StandardScreen.
  var standardScreenScrollMode: StandardScreenScrollMode? {
    get { self[StandardScreenScrollModeKey.self] }
    set { self[StandardScreenScrollModeKey.self] = newValue }
  }
}

// MARK: - StandardScreen

/// The Single Layout Boss.
/// All screens must be wrapped in this.
/// Enforces:
/// 1. Margins (Adaptive)
/// 2. Max Content Width
/// 3. Background Color
/// 4. Navigation Title Application
struct StandardScreen<Content: View, ToolbarItems: ToolbarContent, TitleMenu: View>: View {

  // MARK: Lifecycle

  /// Full initializer with toolbar content and optional title menu.
  /// When titleMenu is provided and shouldUseInlineTitle is true (macOS/iPad),
  /// the menu renders beside the title instead of in the toolbar.
  init(
    title: String,
    layout: LayoutMode = .column,
    scroll: ScrollMode = .automatic,
    pullToSearch: Bool = true,
    @ViewBuilder content: @escaping () -> Content,
    @ToolbarContentBuilder toolbarContent: @escaping () -> ToolbarItems,
    @ViewBuilder titleMenu: @escaping () -> TitleMenu
  ) {
    self.title = title
    self.layout = layout
    self.scroll = scroll
    self.pullToSearch = pullToSearch
    self.content = content
    self.toolbarContent = toolbarContent
    self.titleMenu = titleMenu
  }

  /// Initializer with toolbar content but no title menu.
  init(
    title: String,
    layout: LayoutMode = .column,
    scroll: ScrollMode = .automatic,
    pullToSearch: Bool = true,
    @ViewBuilder content: @escaping () -> Content,
    @ToolbarContentBuilder toolbarContent: @escaping () -> ToolbarItems
  ) where TitleMenu == EmptyView {
    self.title = title
    self.layout = layout
    self.scroll = scroll
    self.pullToSearch = pullToSearch
    self.content = content
    self.toolbarContent = toolbarContent
    titleMenu = { EmptyView() }
  }

  /// Initializer with no toolbar content and no title menu.
  init(
    title: String,
    layout: LayoutMode = .column,
    scroll: ScrollMode = .automatic,
    pullToSearch: Bool = true,
    @ViewBuilder content: @escaping () -> Content
  ) where ToolbarItems == ToolbarItem<Void, EmptyView>, TitleMenu == EmptyView {
    self.title = title
    self.layout = layout
    self.scroll = scroll
    self.pullToSearch = pullToSearch
    self.content = content
    toolbarContent = { ToolbarItem(placement: .automatic) { EmptyView() } }
    titleMenu = { EmptyView() }
  }

  /// Initializer with title menu but no toolbar content.
  /// Use this when the menu should appear beside the title on macOS/iPad
  /// with no additional toolbar items needed.
  init(
    title: String,
    layout: LayoutMode = .column,
    scroll: ScrollMode = .automatic,
    pullToSearch: Bool = true,
    @ViewBuilder content: @escaping () -> Content,
    @ViewBuilder titleMenu: @escaping () -> TitleMenu
  ) where ToolbarItems == ToolbarItem<Void, EmptyView> {
    self.title = title
    self.layout = layout
    self.scroll = scroll
    self.pullToSearch = pullToSearch
    self.content = content
    toolbarContent = { ToolbarItem(placement: .automatic) { EmptyView() } }
    self.titleMenu = titleMenu
  }

  // MARK: Internal

  enum LayoutMode {
    case column // Enforces max width + margins (Default)
    case fullBleed // Edge to edge (Maps, etc)
  }

  enum ScrollMode {
    case automatic // Wraps content in ScrollView
    case disabled // Content is static or provides its own scroll
  }

  /// Debug environment
  @Environment(\.layoutMetrics) var layoutMetrics
  let title: String
  let layout: LayoutMode
  let scroll: ScrollMode
  let pullToSearch: Bool
  @ViewBuilder let content: () -> Content
  let toolbarContent: () -> ToolbarItems
  @ViewBuilder let titleMenu: () -> TitleMenu

  var body: some View {
    PullToSearchHost {
      mainContent
    }
    // On macOS and iPad, render title inline with content (scrollable) rather than in navigation bar.
    // Use empty string to preserve navigation infrastructure while hiding the nav bar title.
    .navigationTitle(shouldUseInlineTitle ? "" : title)
    .toolbar {
      toolbarContent()
      // NOTE: iOS 26 introduces ToolbarItemPlacement.largeTitle for custom large title styling.
      // This would fix navigation animation issues (title turning blue on interrupted back gesture).
      // Re-enable when iOS 26 SDK is available in CI:
      // #if os(iOS)
      // if #available(iOS 26.0, *) {
      //     ToolbarItem(placement: .largeTitle) {
      //         Text(title).foregroundStyle(.primary)
      //     }
      // }
      // #endif
    }
    .applyLayoutWitness()
    #if os(iOS)
      // Only use large title mode for iPhone (compact size class)
      // iPad uses inline title like macOS, so we use .inline to hide the nav bar title area
      .navigationBarTitleDisplayMode(shouldUseInlineTitle ? .inline : .large)
    #endif
      // Reset tint at navigation level to prevent accent color bleeding into nav title
      // during interactive back gesture cancellation. The accent tint is applied to
      // innerContent (inside ScrollView) so controls/buttons still get the correct color.
      .tint(nil)
  }

  // MARK: Private

  #if os(iOS)
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  #endif

  @Environment(\.pullToSearchDisabled) private var pullToSearchDisabled

  /// Whether to render title inline with content (like macOS) instead of in navigation bar.
  /// True for macOS and iPad (regular horizontal size class), false for iPhone (compact).
  private var shouldUseInlineTitle: Bool {
    #if os(macOS)
    return true
    #else
    return horizontalSizeClass != .compact
    #endif
  }

  private var horizontalPadding: CGFloat? {
    switch layout {
    case .fullBleed:
      return 0
    case .column:
      #if os(iOS)
      // Use Apple's platform default inset so content aligns with the system large title.
      return nil
      #else
      return DS.Spacing.Layout.pageMargin
      #endif
    }
  }

  /// Whether the title menu has content (not EmptyView)
  private var hasTitleMenu: Bool {
    TitleMenu.self != EmptyView.self
  }

  /// Inline title view for macOS and iPad - rendered at top of scrollable content area.
  /// Respects the same max width and horizontal padding as content.
  /// When titleMenu is provided, renders it directly beside the title text.
  private var inlineTitleView: some View {
    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
      Text(title)
        .font(DS.Typography.largeTitle)
        .foregroundStyle(DS.Colors.Text.primary)
        .accessibilityIdentifier("screen_title")

      if hasTitleMenu {
        titleMenu()
      }
    }
    .frame(
      maxWidth: layout == .fullBleed ? .infinity : DS.Spacing.Layout.maxContentWidth,
      alignment: .leading
    )
    .padding(.horizontal, horizontalPadding)
    .padding(.top, DS.Spacing.lg)
    .padding(.bottom, DS.Spacing.md)
  }

  private var mainContent: some View {
    ZStack {
      // 1. Unified Background
      // On macOS, exclude top edge to allow toolbar glass/vibrancy effect
      // On iOS, extend under all edges for full-bleed appearance
      #if os(macOS)
      DS.Colors.Background.primary
        .ignoresSafeArea()
      #else
      DS.Colors.Background.primary
        .ignoresSafeArea()
      #endif

      // 2. Content Container
      switch scroll {
      case .automatic:
        ScrollView {
          innerContent
        }
        #if os(iOS)
        // Bottom margin clears floating buttons. Required for safeAreaInset placement.
        .contentMargins(.bottom, DS.Spacing.floatingButtonScrollInset, for: .scrollContent)
        #endif
        .modifier(PullToSearchTrackingConditionalModifier(enabled: pullToSearch && !pullToSearchDisabled))
        .modifier(ScrollEdgeEffectModifier())

      case .disabled:
        innerContent
      }
    }
  }

  @ViewBuilder
  private var innerContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Inline title for macOS and iPad - scrolls with content, aligned with content column
      if shouldUseInlineTitle {
        inlineTitleView
      }

      content()
        .frame(
          maxWidth: layout == .fullBleed ? .infinity : DS.Spacing.Layout.maxContentWidth,
          alignment: .leading
        )
        .padding(.horizontal, horizontalPadding)
    }
    .frame(maxWidth: .infinity, alignment: .top)
    // Apply tint here at content level, not at mainContent level
    // This prevents tint from affecting navigation title during interactive back gestures
    .tint(DS.Colors.accent)
    // Expose scroll mode to child components for contract enforcement
    .environment(
      \.standardScreenScrollMode,
      scroll == .automatic ? .automatic : .disabled
    )
  }
}

// MARK: - ScrollEdgeEffectModifier

/// Applies soft scroll edge effect on iOS 26+ and macOS 26+ for content/toolbar separation.
/// Per HIG: Creates a soft transition between scrollable content and the toolbar area.
private struct ScrollEdgeEffectModifier: ViewModifier {
  func body(content: Content) -> some View {
    // scrollEdgeEffectStyle requires iOS 26/macOS 26 SDK (Xcode 18+).
    // Use compiler check since #available is runtime-only and won't compile without the SDK.
    #if compiler(>=6.2)
    if #available(iOS 26, macOS 26, *) {
      content
        .scrollEdgeEffectStyle(.soft, for: .top)
    } else {
      content
    }
    #else
    content
    #endif
  }
}

// MARK: - StandardScreenPreviewContent

private struct StandardScreenPreviewContent: View {
  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
      Text("Section Header")
        .font(DS.Typography.headline)
        .foregroundColor(DS.Colors.Text.primary)

      Text(
        "This is a representative block of content used to validate margins, max width, typography, and scrolling behavior across StandardScreen variants."
      )
      .font(DS.Typography.body)
      .foregroundColor(DS.Colors.Text.secondary)

      Divider()

      VStack(alignment: .leading, spacing: DS.Spacing.sm) {
        ForEach(0 ..< 60) { i in
          HStack {
            Text("Row \(i + 1)")
              .font(DS.Typography.body)
              .foregroundColor(DS.Colors.Text.primary)
            Spacer()
          }
          if i != 59 { Divider() }
        }
      }
    }
    .padding(.vertical, DS.Spacing.md)
  }
}

#Preview("StandardScreen · Column · Automatic Scroll") {
  NavigationStack {
    StandardScreen(title: "StandardScreen") {
      StandardScreenPreviewContent()
    }
  }
  #if os(macOS)
  .frame(width: 900, height: 700)
  #endif
}

#Preview("StandardScreen · Column · Scroll Disabled") {
  NavigationStack {
    StandardScreen(title: "StandardScreen", layout: .column, scroll: .disabled) {
      StandardScreenPreviewContent()
    }
  }
  #if os(macOS)
  .frame(width: 900, height: 700)
  #endif
}

#Preview("StandardScreen · Full Bleed · Automatic Scroll") {
  NavigationStack {
    StandardScreen(title: "StandardScreen", layout: .fullBleed, scroll: .automatic) {
      StandardScreenPreviewContent()
    }
  }
  #if os(macOS)
  .frame(width: 900, height: 700)
  #endif
}

#Preview("StandardScreen · Full Bleed · Scroll Disabled") {
  NavigationStack {
    StandardScreen(title: "StandardScreen", layout: .fullBleed, scroll: .disabled) {
      StandardScreenPreviewContent()
    }
  }
  #if os(macOS)
  .frame(width: 900, height: 700)
  #endif
}

#Preview("StandardScreen · With Toolbar") {
  NavigationStack {
    StandardScreen(title: "StandardScreen", layout: .column, scroll: .automatic) {
      StandardScreenPreviewContent()
    } toolbarContent: {
      ToolbarItem(placement: .primaryAction) {
        Button {
          // Preview action
        } label: {
          Image(systemName: "ellipsis.circle")
        }
      }
    }
  }
  #if os(macOS)
  .frame(width: 900, height: 700)
  #endif
}

#Preview("StandardScreen · With Title Menu") {
  NavigationStack {
    StandardScreen(title: "StandardScreen", layout: .column, scroll: .automatic) {
      StandardScreenPreviewContent()
    } titleMenu: {
      Menu {
        Button("Edit") { }
        Button("Share") { }
        Button("Delete", role: .destructive) { }
      } label: {
        Image(systemName: "ellipsis.circle")
          .font(.system(size: 20))
      }
    }
  }
  #if os(macOS)
  .frame(width: 900, height: 700)
  #endif
}

#Preview("StandardScreen · Long Title") {
  NavigationStack {
    StandardScreen(
      title: "This is an intentionally long StandardScreen title to verify wrapping at the top and correct collapse behavior when scrolling",
      layout: .column,
      scroll: .automatic
    ) {
      StandardScreenPreviewContent()
    }
  }
  #if os(macOS)
  .frame(width: 900, height: 700)
  #endif
}
