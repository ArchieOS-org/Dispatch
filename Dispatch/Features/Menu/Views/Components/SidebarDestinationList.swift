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
      // Main navigation tabs (now includes Settings)
      ForEach(AppTab.sidebarTabs) { tab in
        SidebarMenuRow(
          tab: tab,
          itemCount: tabCounts[tab] ?? 0,
          overdueCount: tab == .workspace ? overdueCount : 0
        )
        .tag(SidebarDestination.tab(tab))
      }
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
