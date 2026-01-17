//
//  SidebarTabList.swift
//  Dispatch
//
//  macOS sidebar navigation list with selection-based tab switching.
//  Settings is now navigated in-window like other tabs.
//

import SwiftUI

#if os(macOS)
/// Selection-based List for macOS sidebar navigation.
/// Settings is navigated in the main window (not a separate scene).
struct SidebarTabList: View {
  @Binding var selection: AppTab?

  let tabCounts: [AppTab: Int]
  let overdueCount: Int

  var body: some View {
    List(selection: $selection) {
      // Main navigation tabs (now includes Settings)
      ForEach(AppTab.sidebarTabs) { tab in
        SidebarMenuRow(
          tab: tab,
          itemCount: tabCounts[tab] ?? 0,
          overdueCount: tab == .workspace ? overdueCount : 0
        )
      }
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
