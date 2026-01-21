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

  final class Coordinator {
    fileprivate var configuredWindowIDs = Set<ObjectIdentifier>()
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  // MARK: Internal

  func makeNSView(context: Context) -> NSView {
    let view = NSView()

    // `view.window` is nil during construction; defer once to allow attachment.
    DispatchQueue.main.async {
      tryConfigure(view.window, context: context)
    }

    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    tryConfigure(nsView.window, context: context)
  }

  private func tryConfigure(_ window: NSWindow?, context: Context) {
    guard let window else { return }

    // Only configure once per window to avoid repeated mutations during SwiftUI updates.
    let id = ObjectIdentifier(window)
    guard !context.coordinator.configuredWindowIDs.contains(id) else { return }
    context.coordinator.configuredWindowIDs.insert(id)

    #if DEBUG
    print("[MacWindowPolicy] configuring window: \(window) styleMask=\(window.styleMask)")
    #endif

    configure(window)
  }

  // MARK: Private

  private func configure(_ window: NSWindow) {
    // HIG-compliant window configuration.
    // Let the OS handle full-screen, toolbar materials, and traffic lights.

    // 1. Window Transparency for Material Backgrounds
    window.isOpaque = false
    window.backgroundColor = .clear

    // 2. Unified/Transparent Titlebar
    window.titleVisibility = .visible
    window.titlebarAppearsTransparent = false

    if #available(macOS 13.0, *) {
      window.toolbarStyle = .expanded
    }


    // 4. (Removed) Do NOT manually set window.toolbar.
    // SwiftUI manages the toolbar via .windowToolbarStyle().
    // Replacing it manually causes NSRangeException in BarAppearanceBridge.

    // 5. Remove titlebar separator line
    window.titlebarSeparatorStyle = .automatic
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
