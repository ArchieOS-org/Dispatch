//
//  WindowAccessor.swift
//  Dispatch
//
//  Created for DIS-Fix-Window-Style
//

import SwiftUI

#if os(macOS)
import AppKit

/// A view modifier that allows access to the underlying NSWindow
/// Used to remove the unified toolbar and enforce Things 3-style look
struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.callback(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct MacWindowConfigurationModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                WindowAccessor { window in
                    guard let window = window else { return }
                    
                    // Force removal of unified toolbar
                    window.toolbar = nil
                    
                    // Configure title bar
                    window.titleVisibility = .hidden
                    window.titlebarAppearsTransparent = true
                    
                    // Ensure full size content view so content goes behind traffic lights
                    window.styleMask.insert(.fullSizeContentView)
                    
                    // Optional: Hide the title text permanently
                    window.title = ""
                }
            )
    }
}

extension View {
    /// Configures the macOS window to have no toolbar and a hidden title bar (Things 3 style).
    /// Content will start immediately at the top of the window, behind the traffic lights.
    func configureMacWindow() -> some View {
        self.modifier(MacWindowConfigurationModifier())
    }
}
#else
// No-op for iOS
extension View {
    func configureMacWindow() -> some View {
        self
    }
}
#endif
