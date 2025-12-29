//
//  MacWindowPolicy.swift
//  Dispatch
//
//  Created for Dispatch Layout Unification
//

import SwiftUI

#if os(macOS)
import AppKit

/// A minimal window configuration policy that respects native macOS behavior
/// while enabling the standard modern "transparent titlebar" look.
///
/// Usage: Apply via `.background(MacWindowPolicy())` on the root view.
struct MacWindowPolicy: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                configure(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            configure(window)
        }
    }

    private func configure(_ window: NSWindow) {
        // Option A Strategy: Stop fighting the OS.
        // We do NOT remove the toolbar. We do NOT force title visibility constantly.
        
        // 1. Unified/Transparent Titlebar
        // This allows the window chrome to blend nicely, but we do NOT force content underneath
        // by removing .fullSizeContentView. This lets standard layout handle the top inset.
        window.titlebarAppearsTransparent = true
        
        // 2. Hide Native Title Text
        // We render a custom "Things 3" style left-aligned header in the content view on macOS.
        // So we hide the default center-aligned window title.
        window.titleVisibility = .hidden
        
        // 3. Respect Native Layout (Fix Overlap)
        // We explicitly REMOVE .fullSizeContentView.
        // This stops content from flowing under the toolbar, letting the OS handle the safe area.
        // This fixes the "pushed to top" / overlap issues.
        if window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.remove(.fullSizeContentView)
        }
    }
}

extension View {
    /// Applies the standard Mac Window Policy.
    /// Should only be called once from the AppShell.
    func applyMacWindowPolicy() -> some View {
        self.background(MacWindowPolicy())
    }
}
#else
extension View {
    func applyMacWindowPolicy() -> some View {
        self
    }
}
#endif
