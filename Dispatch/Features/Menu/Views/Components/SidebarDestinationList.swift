//
//  SidebarDestinationList.swift
//  Dispatch
//
//  macOS sidebar navigation list with selection-based destination switching.
//  Supports both tabs and stages as first-class destinations.
//

import SwiftUI

#if os(macOS)
/// Selection-based List for macOS sidebar navigation.
/// Stages are accessed via StageCardsHeader above, not inline rows.
struct SidebarDestinationList: View {
  @Binding var selection: SidebarDestination?
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
        .tag(SidebarDestination.tab(tab))
      }

      Divider()
        .padding(.vertical, DS.Spacing.sm)

      // Settings opens Settings scene via SettingsLink
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

#Preview("Sidebar Destination List") {
  SidebarDestinationList(
    selection: .constant(.tab(.workspace)),
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
