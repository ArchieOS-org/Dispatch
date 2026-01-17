//
//  AudienceFilterButton.swift
//  Dispatch
//
//  Universal component for the Audience Filter (All/Admin/Marketing).
//  Implements the "Jobs Standard" Mac Look as the golden reference.
//
//  Created for Unification.
//

import SwiftUI

/// Single Source of Truth for the Audience Filter UI.
/// Used in:
/// - macOS Bottom Toolbar
/// - iOS Floating Buttons
/// - iPad Detail Toolbar
struct AudienceFilterButton: View {

  // MARK: Internal

  /// The current filter state (Input)
  let lens: AudienceLens

  /// The cycle action (Output) - Pure "One Boss" flow
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: lens.icon)
        .symbolRenderingMode(.monochrome)
        .foregroundStyle(lens == .all ? .secondary : lens.tintColor)
        .font(.system(size: 17, weight: .semibold)) // Legible Toolbar Weight
        .imageScale(.medium) // Balance within frame
        #if os(macOS)
        .frame(width: DS.Spacing.bottomToolbarButtonSize, height: DS.Spacing.bottomToolbarButtonSize)
        #else
        .frame(width: DS.Spacing.minTouchTarget, height: DS.Spacing.minTouchTarget)
        #endif
        .background {
          #if os(macOS)
          RoundedRectangle(cornerRadius: 6)
            .fill(isHovering ? Color.primary.opacity(0.08) : Color.clear)
          #else
          Color.clear
          #endif
        }
        .contentShape(Rectangle()) // Ensure entire frame is hit-testable
    }
    .buttonStyle(.plain) // Essential for standardizing across platforms
    #if os(macOS)
      .onHover { isHovering = $0 }
    #endif
      .accessibilityIdentifier("AudienceFilterButton")
      // Regression Lock: Encodes symbol name to prove visual change
      .accessibilityValue("\(lens.rawValue)|\(lens.icon)")
  }

  // MARK: Private

  #if os(macOS)
  @State private var isHovering = false
  #endif

}

#Preview {
  HStack {
    AudienceFilterButton(lens: .all, action: { })
    AudienceFilterButton(lens: .admin, action: { })
    AudienceFilterButton(lens: .marketing, action: { })
  }
  .padding()
}
