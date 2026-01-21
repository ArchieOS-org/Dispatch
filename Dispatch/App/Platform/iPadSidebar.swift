//
//  iPadSidebar.swift
//  Dispatch
//
//  Created for Dispatch Navigation Redesign
//

import SwiftUI

struct iPadSidebar: View {
  
  // MARK: Lifecycle
  
  init(
    selection: Binding<SidebarDestination>,
    stageCounts: [ListingStage: Int],
    tabCounts: [AppTab: Int],
    overdueCount: Int,
    onSelectStage: @escaping (ListingStage) -> Void
  ) {
    self._selection = selection
    self.stageCounts = stageCounts
    self.tabCounts = tabCounts
    self.overdueCount = overdueCount
    self.onSelectStage = onSelectStage
  }
  
  // MARK: Internal
  
  @Binding var selection: SidebarDestination
  
  var body: some View {
    List(selection: $selection) {
      // Stage Cards
      // Note: On iPad, List .sidebar style handles standard headers well.
      
      Section {
        StageCardsSection(
          stageCounts: stageCounts,
          onSelectStage: onSelectStage
        )
      }
      .listRowInsets(EdgeInsets(
        top: DS.Spacing.sm,
        leading: DS.Spacing.md,
        bottom: DS.Spacing.md,
        trailing: DS.Spacing.md
      ))
      .listRowSeparator(.hidden)
      .listRowBackground(Color.clear)
      
      // Navigation Tabs
      Section {
        ForEach(AppTab.sidebarTabs) { tab in
          SidebarMenuRow(
            tab: tab,
            itemCount: tabCounts[tab] ?? 0,
            overdueCount: tab == .workspace ? overdueCount : 0
          )
          .tag(SidebarDestination.tab(tab))
        }
      }
      .listRowBackground(Color.clear)
      
      // Settings Section (Bottom)
      Section {
        SidebarMenuRow(
            tab: .settings,
            itemCount: 0,
            overdueCount: 0
        )
        .tag(SidebarDestination.tab(.settings))
      }
      .listRowBackground(Color.clear)
    }
    .listStyle(.sidebar)
  }
  
  // MARK: Private
  
  private let stageCounts: [ListingStage: Int]
  private let tabCounts: [AppTab: Int]
  private let overdueCount: Int
  private let onSelectStage: (ListingStage) -> Void
  
}
