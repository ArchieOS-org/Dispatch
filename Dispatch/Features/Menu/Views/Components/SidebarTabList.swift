//
//  SidebarTabList.swift
//  Dispatch
//
//  macOS sidebar navigation list with selection-based tab switching.
//  Uses SettingsLink for Settings to open the Settings scene (Cmd+,).
//

import SwiftUI

#if os(macOS)
/// Selection-based List for macOS sidebar navigation.
/// Settings row opens Settings scene via SettingsLink.
struct SidebarTabList: View {
  @Binding var selection: AppTab?

  let tabCounts: [AppTab: Int]
  let overdueCount: Int

  var body: some View {
    List(selection: $selection) {
      // Main navigation tabs
      ForEach(AppTab.sidebarTabs) { tab in
        SidebarMenuRow(
          tab: tab,
          itemCount: tabCounts[tab] ?? 0,
          overdueCount: tab == .workspace ? overdueCount : 0
        )
      }

      Divider()
        .padding(.vertical, DS.Spacing.sm)

      // Settings opens Settings scene via SettingsLink (not NavigationStack push)
      SettingsLink {
        SidebarMenuRow(
          tab: .settings,
          itemCount: 0,
          overdueCount: 0
        )
      }
      .buttonStyle(.plain)
    }
    .listStyle(.sidebar)
    .scrollContentBackground(.hidden)
  }
}

// MARK: - Preview

#Preview("Sidebar Tab List") {
  SidebarTabList(
    selection: .constant(.workspace),
    tabCounts: [
      .workspace: 12,
      .properties: 45,
      .listings: 23,
      .realtors: 67
    ],
    overdueCount: 3
  )
  .frame(width: 240)
}
#endif
