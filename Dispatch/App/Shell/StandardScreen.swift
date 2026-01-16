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
    @Environment(\.isFullScreen) private var isFullScreen

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
        .navigationTitle(title)
        .toolbar {
            toolbarContent()
            #if os(iOS)
            // Custom large title with explicit foreground style.
            // Per Apple docs: .largeTitle placement "takes precedence over the value
            // provided to the View.navigationTitle(_:) modifier".
            // This fixes navigation animation issues where:
            // 1. Title turns blue/accent on interrupted back gesture
            // 2. Title moves at different rate than content during gesture
            // By using a SwiftUI Text view with explicit .foregroundStyle(.primary),
            // we ensure the title:
            // - Uses SwiftUI's animation system (not UIKit nav bar animation)
            // - Has explicit color that can't inherit tint
            // - Animates linearly with content during gestures
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .largeTitle) {
                    Text(title)
                        .foregroundStyle(.primary)
                }
            }
            #endif
        }
        .applyLayoutWitness()
        #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            // Reset color scheme for navigation bar to prevent accent tint from
            // affecting title during interactive back gesture cancellation.
            // nil = use system default (adapts to light/dark mode automatically).
            .toolbarColorScheme(nil, for: .navigationBar)
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

    /// Top padding for macOS content header.
    /// In full-screen mode with hidden toolbar, we need extra padding to prevent
    /// content from being too close to the top of the screen.
    private var macOSTopPadding: CGFloat {
        #if os(macOS)
        // When in full-screen mode, the toolbar hides by default (onHover visibility).
        // Add extra padding to account for the missing titlebar area (~20pt extra).
        // Normal mode: 8pt (DS.Spacing.sm)
        // Full-screen mode: 28pt (8pt + 20pt for hidden titlebar)
        isFullScreen ? DS.Spacing.sm + DS.Spacing.Layout.topHeaderPadding : DS.Spacing.sm
        #else
        DS.Spacing.sm
        #endif
    }

    private var mainContent: some View {
        ZStack {
            // 1. Unified Background
            DS.Colors.Background.primary
                .ignoresSafeArea()

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

            case .disabled:
                innerContent
            }
        }
    }

    @ViewBuilder
    private var innerContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            #if os(macOS)
                // macOS: Custom static header (Things 3 style)
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(DS.Colors.Text.primary)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, macOSTopPadding)
                    .padding(.bottom, DS.Spacing.Layout.titleContentSpacing)
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
        #if os(macOS)
        .navigationTitle("") // Hide system title on Mac in favor of our custom header
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
