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
    
    let useContentPadding: Bool
    
    init(
        @ViewBuilder title: @escaping () -> TitleContent,
        useContentPadding: Bool = true,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder headerActions: @escaping () -> Actions = { EmptyView() }
    ) {
        self.title = title
        self.useContentPadding = useContentPadding
        self.content = content
        self.headerActions = headerActions
    }
    
    // Convenience init for String title
    init(
        title: String,
        useContentPadding: Bool = true,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder headerActions: @escaping () -> Actions = { EmptyView() }
    ) where TitleContent == Text {
        self.title = {
            Text(title)
                .font(.system(size: DS.Spacing.Layout.largeTitleSize, weight: .bold))
                .foregroundColor(.primary)
        }
        self.useContentPadding = useContentPadding
        self.content = content
        self.headerActions = headerActions
    }
    
    var body: some View {
        ZStack {
            #if os(macOS)
            DS.Colors.Background.primary
                .ignoresSafeArea(.all, edges: .all)
            #endif
            
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
                EmptyView()
                #endif
                
                content()
                    .padding(.horizontal, useContentPadding ? DS.Spacing.Layout.pageMargin : 0)
            }
        }
        #if os(macOS)
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .windowToolbar)
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
