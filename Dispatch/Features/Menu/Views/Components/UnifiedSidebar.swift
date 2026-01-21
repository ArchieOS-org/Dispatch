//
//  UnifiedSidebar.swift
//  Dispatch
//
//  Unified sidebar content for iPad and macOS.
//  Provides consistent sidebar UI across platforms with 80%+ code sharing.
//
//  Usage:
//  - macOS: Use inside ResizableSidebar container
//  - iPad: Use inside NavigationSplitView sidebar column
//

import SwiftUI

// MARK: - UnifiedSidebarContent

/// Shared sidebar content component for iPad and macOS.
/// Provides stage cards header and navigation menu in a single List.
///
/// This component handles:
/// - Material background (thinMaterial)
/// - Selection states via List(selection:)
/// - Platform-adaptive spacing
/// - Safe area handling for Dynamic Island/notch
///
/// Platform-specific containers:
/// - macOS: `ResizableSidebar` provides drag-to-resize
/// - iPad: `NavigationSplitView` provides native split behavior
struct UnifiedSidebarContent: View {

  /// Stage counts for the stage cards header
  let stageCounts: [ListingStage: Int]

  /// Tab counts for inline display in sidebar rows.
  /// Note: These replace the TabView `.badge()` modifiers from the previous iPhone-only
  /// implementation. Sidebar rows show counts inline (e.g., "Properties 8") rather than
  /// as iOS tab bar badges. See SidebarMenuRow for the display implementation.
  let tabCounts: [AppTab: Int]

  /// Overdue count for workspace badge
  let overdueCount: Int

  /// Currently selected destination (binding for List selection)
  let selection: Binding<SidebarDestination?>

  /// Callback when a stage card is selected
  let onSelectStage: (ListingStage) -> Void

  var body: some View {
    List(selection: selection) {
      // Stage cards section (scrolls with tabs)
      Section {
        StageCardsSection(
          stageCounts: stageCounts,
          onSelectStage: onSelectStage
        )
      }
      .listRowInsets(EdgeInsets(
        top: DS.Spacing.sm,
        leading: 0,
        bottom: DS.Spacing.md,
        trailing: 0
      ))
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
      .accessibilityElement(children: .contain)
      .accessibilityLabel("Listing stages")

      // Navigation tabs section
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
      .accessibilityElement(children: .contain)
      .accessibilityLabel("Navigation")
    }
    .listStyle(.sidebar)
    #if os(iOS)
      .scrollContentBackground(.hidden)
      // Remove blue selection highlight on iPad sidebar (DIS-67)
      .tint(.clear)
    #endif
  }

}

// MARK: - Previews

#Preview("Unified Sidebar Content") {
  UnifiedSidebarContent(
    stageCounts: [
      .pending: 5,
      .workingOn: 3,
      .live: 12,
      .sold: 8,
      .reList: 2,
      .done: 45
    ],
    tabCounts: [
      .workspace: 15,
      .properties: 8,
      .listings: 12,
      .realtors: 6
    ],
    overdueCount: 3,
    selection: .constant(SidebarDestination.tab(.workspace)),
    onSelectStage: { _ in }
  )
  .frame(width: 280)
}

#Preview("Unified Sidebar - Dark Mode") {
  UnifiedSidebarContent(
    stageCounts: [
      .pending: 5,
      .workingOn: 3,
      .live: 12,
      .sold: 8,
      .reList: 2,
      .done: 45
    ],
    tabCounts: [
      .workspace: 15,
      .properties: 8,
      .listings: 12,
      .realtors: 6
    ],
    overdueCount: 0,
    selection: .constant(SidebarDestination.tab(.listings)),
    onSelectStage: { _ in }
  )
  .frame(width: 280)
  .preferredColorScheme(.dark)
}
