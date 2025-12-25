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

    func makeCoordinator() -> Coordinator {
        Coordinator(callback: callback)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.setup(view: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class Coordinator: NSObject {
        var callback: (NSWindow?) -> Void
        
        // Hold weak reference to window to avoid cycles, though notification center handles this well mostly
        private weak var observedWindow: NSWindow?
        
        init(callback: @escaping (NSWindow?) -> Void) {
            self.callback = callback
            super.init()
        }
        
        func setup(view: NSView) {
            // Wait for window to be attached
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                guard let window = view.window else { return }
                
                // If we are already observing this window, skip
                if self.observedWindow == window { return }
                
                self.observedWindow = window
                
                // Configure immediately
                self.callback(window)
                
                // Observe window becoming key to re-assert preferences
                // SwiftUI/AppKit likes to reset toolbars on focus changes
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(self.handleWindowNotification(_:)),
                    name: NSWindow.didBecomeKeyNotification,
                    object: window
                )
                
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(self.handleWindowNotification(_:)),
                    name: NSWindow.didBecomeMainNotification,
                    object: window
                )
                
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(self.handleWindowNotification(_:)),
                    name: NSWindow.didResignKeyNotification,
                    object: window
                )
                
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(self.handleWindowNotification(_:)),
                    name: NSWindow.didResignMainNotification,
                    object: window
                )

                // Also listen for size changes just in case
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(self.handleWindowNotification(_:)),
                    name: NSWindow.didResizeNotification,
                    object: window
                )
            }
        }
        
        @objc func handleWindowNotification(_ notification: Notification) {
            guard let window = notification.object as? NSWindow else { return }
            // Re-apply configuration immediately
            self.callback(window)
            
            // And again on next runloop to override any SwiftUI resets that happen during the event
            DispatchQueue.main.async { [weak self] in
                self?.callback(window)
            }
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

struct MacWindowConfigurationModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                WindowAccessor { window in
                    guard let window = window else { return }
                    
                    // Force removal of unified toolbar
                    // We must set this to nil to get the Things 3 look
                    if window.toolbar != nil {
                        window.toolbar = nil
                    }
                    
                    // Configure title bar
                    window.titleVisibility = .hidden
                    window.titlebarAppearsTransparent = true
                    
                    // Ensure full size content view so content goes behind traffic lights
                    if !window.styleMask.contains(.fullSizeContentView) {
                        window.styleMask.insert(.fullSizeContentView)
                    }
                    
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
