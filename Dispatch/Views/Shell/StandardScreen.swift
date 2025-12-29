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
            .navigationTitle(title) // StandardScreen is the Source of Truth
            .toolbar {
                toolbarContent()
            }
            .applyLayoutWitness() // Debug overlay (only visible if enabled in AppShell)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline) // Standardize on inline for now, or make configurable
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
            // Left-Aligned "Things 3" Header
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(DS.Colors.Text.primary)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.sm)
            #endif
            
            content()
                .frame(maxWidth: layout == .fullBleed ? .infinity : DS.Spacing.Layout.maxContentWidth)
                .padding(.horizontal, horizontalPadding)
        }
        .frame(maxWidth: .infinity, alignment: .top) // Align Top
        #if os(macOS)
        .navigationTitle("") // Hide system title on Mac in favor of our custom header
        #endif
    }
    
    private var horizontalPadding: CGFloat {
        switch layout {
        case .fullBleed: return 0
        case .column: return DS.Spacing.Layout.pageMargin
        }
    }
}
