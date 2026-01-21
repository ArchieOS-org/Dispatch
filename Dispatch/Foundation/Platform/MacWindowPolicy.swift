//
//  MacWindowPolicy.swift
//  Dispatch
//
//  Created for Dispatch Layout Unification
//
//  Simplified HIG-compliant window configuration.
//  macOS 26+: Let the system handle toolbar materials via SwiftUI modifiers.
//

import SwiftUI

#if os(macOS)
import AppKit

// MARK: - MacWindowPolicy

/// A minimal window configuration policy that respects native macOS behavior
/// while enabling the standard modern "transparent titlebar" look.
///
/// Usage: Apply via `.background(MacWindowPolicy())` on the root view.
struct MacWindowPolicy: NSViewRepresentable {

  // MARK: Internal

  func makeNSView(context _: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async {
      if let window = view.window {
        configure(window)
      }
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context _: Context) {
    if let window = nsView.window {
      configure(window)
    }
  }

  // MARK: Private

  private func configure(_ window: NSWindow) {
    // HIG-compliant window configuration.
    // Let the OS handle full-screen, toolbar materials, and traffic lights.

    // 1. Window Transparency for Material Backgrounds
    window.isOpaque = false
    window.backgroundColor = .clear

    // 2. Unified/Transparent Titlebar
    window.titlebarAppearsTransparent = true

    // 3. Enable Full-Size Content View
    if !window.styleMask.contains(.fullSizeContentView) {
      window.styleMask.insert(.fullSizeContentView)
    }

    // 4. Remove titlebar separator line
    // Note: SwiftUI's .toolbar modifier on NavigationSplitView creates the NSToolbar.
    // Manual toolbar assignment here would conflict with SwiftUI's KVO observers.
    window.titlebarSeparatorStyle = .none
  }

}

extension View {
  /// Applies the standard Mac Window Policy.
  /// Should only be called once from the AppShell.
  func applyMacWindowPolicy() -> some View {
    background(MacWindowPolicy())
  }
}

#else
extension View {
  func applyMacWindowPolicy() -> some View {
    self
  }
}
#endif
