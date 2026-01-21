//
//  MacSidebar.swift
//  Dispatch
//
//  Created for Dispatch Navigation Redesign
//

import SwiftUI

struct MacSidebar: View {
  
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
      // Platform Specific Header Space for Traffic Lights
      // We rely on safeAreaInset in RootView, but the List header naturally provides some space.
      // However, for visual overlap, we might need specific padding if the List goes under.
      // For now, standard Sidebar List Style usually handles this well with fullSizeContentView.
      
      // Stage Cards
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
    .scrollContentBackground(.hidden)
    .background(.thinMaterial) // Sidebar material
  }
  
  // MARK: Private
  
  private let stageCounts: [ListingStage: Int]
  private let tabCounts: [AppTab: Int]
  private let overdueCount: Int
  private let onSelectStage: (ListingStage) -> Void
  
}
