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
        // This allows content to flow under the window chrome (Traffic Lights).
        window.titlebarAppearsTransparent = true
        
        // 2. Hide Native Title Text (if we want the "clean" look)
        // We can let the toolbar item provide the title, or use standard .navigationTitle.
        // If we set this to .hidden, standard .navigationTitle won't show in the *center*
        // but it will show in the window tab/sidebar depending on style.
        // For "Things 3" minimal look where the title is often a custom label or
        // inline toolbar item, hiding the default center title is correct.
        window.titleVisibility = .hidden
        
        // 3. Full Size Content
        // Crucial for the "under titlebar" effect.
        if !window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.insert(.fullSizeContentView)
        }
        
        // 4. Stable Toolbar
        // We explicitly ensure the toolbar is visible to prevent corner radius glitches.
        // Ideally AppShell has already attached a toolbar via SwiftUI modifiers.
        // This is just a safeguard.
        // Note: We do NOT set window.toolbar = nil.
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
