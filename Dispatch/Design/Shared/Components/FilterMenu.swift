//
//  FilterMenu.swift
//  Dispatch
//
//  Toolbar filter menu for iPad and macOS.
//  Shows current filter state in label with checkmark selection in menu.
//

import SwiftUI

/// A toolbar menu for filtering by audience on iPad and macOS.
/// Shows current filter state at-a-glance: "Filter: All", "Filter: Admin", etc.
/// Uses Picker inside Menu for automatic checkmark on active selection.
struct FilterMenu: View {

  // MARK: Internal

  @Binding var audience: AudienceLens

  var body: some View {
    Menu {
      Picker(selection: $audience) {
        ForEach(AudienceLens.allCases, id: \.self) { lens in
          Label(lens.label, systemImage: lens.icon)
            .tag(lens)
        }
      } label: {
        EmptyView() // Picker content only, label handled by Menu
      }
    } label: {
      Label {
        Text("Filter: \(audience.label)")
      } icon: {
        Image(systemName: audience.icon)
          .foregroundStyle(audience.tintColor)
      }
    }
    .menuIndicator(.visible)
    .accessibilityLabel("Filter")
    .accessibilityValue(audience.label)
  }
}

// MARK: - Preview

#Preview("FilterMenu - All") {
  FilterMenu(audience: .constant(.all))
    .padding()
}

#Preview("FilterMenu - Admin") {
  FilterMenu(audience: .constant(.admin))
    .padding()
}

#Preview("FilterMenu - Marketing") {
  FilterMenu(audience: .constant(.marketing))
    .padding()
}
