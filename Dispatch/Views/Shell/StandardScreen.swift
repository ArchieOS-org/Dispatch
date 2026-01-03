//
//  StandardScreen.swift
//  Dispatch
//
//  Created for Dispatch Architecture Unification
//

import SwiftUI

/// The Single Layout Boss.
/// All screens must be wrapped in this.
/// Enforces:
/// 1. Margins (Adaptive)
/// 2. Max Content Width
/// 3. Background Color
/// 4. Navigation Title Application
struct StandardScreen<Content: View, ToolbarItems: ToolbarContent>: View {
    let title: String
    let layout: LayoutMode
    let scroll: ScrollMode
    @ViewBuilder let content: () -> Content
    let toolbarContent: () -> ToolbarItems
    
    // Debug environment
    @Environment(\.layoutMetrics) var layoutMetrics

    enum LayoutMode {
        case column      // Enforces max width + margins (Default)
        case fullBleed   // Edge to edge (Maps, etc)
    }
    
    enum ScrollMode {
        case automatic   // Wraps content in ScrollView
        case disabled    // Content is static or provides its own scroll
    }
    
    init(
        title: String,
        layout: LayoutMode = .column,
        scroll: ScrollMode = .automatic,
        @ViewBuilder content: @escaping () -> Content,
        @ToolbarContentBuilder toolbarContent: @escaping () -> ToolbarItems
    ) {
        self.title = title
        self.layout = layout
        self.scroll = scroll
        self.content = content
        self.toolbarContent = toolbarContent
    }
    
    init(
        title: String,
        layout: LayoutMode = .column,
        scroll: ScrollMode = .automatic,
        @ViewBuilder content: @escaping () -> Content
    ) where ToolbarItems == ToolbarItem<(), EmptyView> {
        self.title = title
        self.layout = layout
        self.scroll = scroll
        self.content = content
        self.toolbarContent = { ToolbarItem(placement: .automatic) { EmptyView() } }
    }
    
    var body: some View {
        mainContent
            .navigationTitle(title)
            .toolbar {
                toolbarContent()
            }
            .applyLayoutWitness()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.automatic)
            #endif
    }
    
    @ViewBuilder
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
                .padding(.top, DS.Spacing.sm)
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
        #if os(macOS)
        .navigationTitle("") // Hide system title on Mac in favor of our custom header
        #endif
    }
    
    private var horizontalPadding: CGFloat? {
        switch layout {
        case .fullBleed:
            return 0
        case .column:
            #if os(iOS)
            // Use Apple’s platform default inset so content aligns with the system large title.
            return nil
            #else
            return DS.Spacing.Layout.pageMargin
            #endif
        }
    }
}

// MARK: - Previews

private struct StandardScreenPreviewContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text("Section Header")
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.Text.primary)

            Text("This is a representative block of content used to validate margins, max width, typography, and scrolling behavior across StandardScreen variants.")
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.Text.secondary)

            Divider()

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                ForEach(0..<60) { i in
                    HStack {
                        Text("Row \(i + 1)")
                            .font(DS.Typography.body)
                            .foregroundColor(DS.Colors.Text.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(DS.Colors.Text.tertiary)
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
