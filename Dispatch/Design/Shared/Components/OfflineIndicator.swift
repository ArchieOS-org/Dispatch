//
//  OfflineIndicator.swift
//  Dispatch
//
//  Design System component for offline status indicator
//

import SwiftUI

/// A small orange dot that indicates the app is offline.
/// Non-interactive visual indicator positioned in the bottom left of the screen.
struct OfflineIndicator: View {
  var body: some View {
    Circle()
      .fill(Color.orange)
      .frame(width: 12, height: 12)
      .accessibilityHidden(true)
  }
}

#Preview {
  OfflineIndicator()
    .padding()
}
