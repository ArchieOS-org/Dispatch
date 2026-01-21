//
//  MacWindowPolicy.swift
//  Dispatch
//
//  Created for Dispatch Layout Unification
//

import SwiftUI

// Helper view to access NSWindow
private struct WindowAccessor: NSViewRepresentable {
  var callback: (NSWindow) -> Void

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async {
      if let window = view.window {
        self.callback(window)
      }
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {}
}

