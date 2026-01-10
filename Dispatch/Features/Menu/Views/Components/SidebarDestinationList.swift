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
/// Renders stage rows with colored icons followed by main tab rows.
struct SidebarDestinationList: View {
  @Binding var selection: SidebarDestination?
  let tabCounts: [AppTab: Int]
  let stageCounts: [ListingStage: Int]
  let overdueCount: Int

  var body: some View {
    List(selection: $selection) {
      // Stage destinations (smart lists with colored icons)
      ForEach(ListingStage.allCases, id: \.self) { stage in
        SidebarStageRow(
          stage: stage,
          count: stageCounts[stage] ?? 0
        )
        .tag(SidebarDestination.stage(stage))
      }

      Divider()
        .padding(.vertical, DS.Spacing.sm)

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

/// Sidebar row for a stage destination with colored icon
private struct SidebarStageRow: View {
  let stage: ListingStage
  let count: Int

  var body: some View {
    Label {
      HStack {
        Text(stage.displayName)
          .font(DS.Typography.body)
        Spacer()
        if stage != .done, count > 0 {
          Text("\(count)")
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
        }
      }
    } icon: {
      Image(systemName: stage.icon)
        .foregroundStyle(stage.color)
        .font(.system(size: 16, weight: .medium))
    }
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
    stageCounts: [
      .pending: 5,
      .workingOn: 3,
      .live: 12,
      .sold: 8,
      .reList: 2,
      .done: 45
    ],
    overdueCount: 3
  )
  .frame(width: 240)
}
#endif
