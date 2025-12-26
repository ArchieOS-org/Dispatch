//
//  StandardPageLayout.swift
//  Dispatch
//
//  Created by Dispatch AI on 2025-12-26.
//

import SwiftUI

/// A standardized page layout component that enforces the "Things 3" spacing system.
/// Uses `DS.Layout` tokens to ensure consistent margins, traffic light clearance, and typography.
struct StandardPageLayout<TitleContent: View, Content: View, Actions: View>: View {
    @ViewBuilder let title: () -> TitleContent
    @ViewBuilder let content: () -> Content
    @ViewBuilder let headerActions: () -> Actions
    
    init(
        @ViewBuilder title: @escaping () -> TitleContent,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder headerActions: @escaping () -> Actions = { EmptyView() }
    ) {
        self.title = title
        self.content = content
        self.headerActions = headerActions
    }
    
    // Convenience init for String title
    init(
        title: String,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder headerActions: @escaping () -> Actions = { EmptyView() }
    ) where TitleContent == Text {
        self.title = {
            Text(title)
                .font(.system(size: DS.Spacing.Layout.largeTitleSize, weight: .bold))
                .foregroundColor(.primary)
        }
        self.content = content
        self.headerActions = headerActions
    }
    
    var body: some View {
        VStack(spacing: 0) {
            #if os(macOS)
            // Things 3 Style: Custom Large Title Header
            HStack {
                title() // Render custom title view
                Spacer()
                headerActions()
            }
            .padding(.horizontal, DS.Spacing.Layout.pageMargin)
            .padding(.top, DS.Spacing.Layout.topHeaderPadding)
            .padding(.bottom, DS.Spacing.Layout.titleBottomSpacing)
            #elseif os(iOS)
            // iOS might retain native navigation bar, or use this if we want strict consistency
            // For now, mirroring macOS logic but respecting safe area
            // Ideally, iOS uses native .navigationTitle, but if this is shared...
            // Let's defer iOS specifics and focus on macOS excellence first.
            EmptyView()
            #endif

            content()
                .padding(.horizontal, DS.Spacing.Layout.pageMargin) // Apply standard content margins
        }
        #if os(macOS)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .navigationTitle("")
        #endif
    }
}

// MARK: - Preview
#Preview {
    StandardPageLayout(title: "Preview Page") {
        Text("Content goes here")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    } headerActions: {
        Button(action: {}) {
            Image(systemName: "plus")
        }
    }
}
