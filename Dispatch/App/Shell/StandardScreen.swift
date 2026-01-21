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
struct StandardScreen<Content: View, ToolbarItems: ToolbarContent>: View {

  // MARK: Lifecycle

  init(
    title: String,
    layout: LayoutMode = .column,
    scroll: ScrollMode = .automatic,
    pullToSearch: Bool = true,
    @ViewBuilder content: @escaping () -> Content,
    @ToolbarContentBuilder toolbarContent: @escaping () -> ToolbarItems
  ) {
    self.title = title
    self.layout = layout
    self.scroll = scroll
    self.pullToSearch = pullToSearch
    self.content = content
    self.toolbarContent = toolbarContent
  }

  init(
    title: String,
    layout: LayoutMode = .column,
    scroll: ScrollMode = .automatic,
    pullToSearch: Bool = true,
    @ViewBuilder content: @escaping () -> Content
  ) where ToolbarItems == ToolbarItem<Void, EmptyView> {
    self.title = title
    self.layout = layout
    self.scroll = scroll
    self.pullToSearch = pullToSearch
    self.content = content
    toolbarContent = { ToolbarItem(placement: .automatic) { EmptyView() } }
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

  var body: some View {
    PullToSearchHost {
      mainContent
    }
    // On macOS, render title inline with content (scrollable) rather than in navigation bar.
    // Use empty string to preserve navigation infrastructure while hiding the nav bar title.
    #if os(macOS)
    .navigationTitle("")
    #else
    .navigationTitle(title)
    #endif
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
      .navigationBarTitleDisplayMode(.large)
    #endif
      // Reset tint at navigation level to prevent accent color bleeding into nav title
      // during interactive back gesture cancellation. The accent tint is applied to
      // innerContent (inside ScrollView) so controls/buttons still get the correct color.
      .tint(nil)
  }

  // MARK: Private

  @Environment(\.pullToSearchDisabled) private var pullToSearchDisabled

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

  #if os(macOS)
  /// Inline title view for macOS - rendered at top of scrollable content area.
  /// Respects the same max width and horizontal padding as content.
  private var inlineTitleView: some View {
    Text(title)
      .font(DS.Typography.largeTitle)
      .foregroundStyle(DS.Colors.Text.primary)
      .frame(
        maxWidth: layout == .fullBleed ? .infinity : DS.Spacing.Layout.maxContentWidth,
        alignment: .leading
      )
      .padding(.horizontal, horizontalPadding)
      .padding(.top, DS.Spacing.lg)
      .padding(.bottom, DS.Spacing.md)
  }
  #endif

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
        // Add bottom margin to clear floating buttons on iPhone
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
      #if os(macOS)
      // Inline title for macOS - scrolls with content, aligned with content column
      inlineTitleView
      #endif

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
    if #available(iOS 26, macOS 26, *) {
      content
        .scrollEdgeEffectStyle(.soft, for: .top)
    } else {
      content
    }
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
