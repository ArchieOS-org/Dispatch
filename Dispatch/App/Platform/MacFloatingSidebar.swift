//
//  MacFloatingSidebar.swift
//  Dispatch
//
//  Floating sidebar panel for macOS.
//  Decoupled from toolbar - animates independently via ZStack overlay.
//

#if os(macOS)
import SwiftUI

/// A floating sidebar panel that overlays the main content.
/// Uses thinMaterial for glass effect and push transition for animation.
struct MacFloatingSidebar: View {

  let stageCounts: [ListingStage: Int]
  let tabCounts: [AppTab: Int]
  let overdueCount: Int
  let selection: Binding<SidebarDestination?>
  let onSelectStage: (ListingStage) -> Void

  var body: some View {
    UnifiedSidebarContent(
      stageCounts: stageCounts,
      tabCounts: tabCounts,
      overdueCount: overdueCount,
      selection: selection,
      onSelectStage: onSelectStage
    )
    .frame(width: DS.Spacing.sidebarDefaultWidth)
    .frame(maxHeight: .infinity)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.md))
    .shadow(color: .black.opacity(0.15), radius: 8, x: 2, y: 0)
    .padding(.leading, DS.Spacing.sm)
    .padding(.vertical, DS.Spacing.sm)
  }

}

#Preview("Floating Sidebar") {
  ZStack(alignment: .leading) {
    Color.gray.opacity(0.2)
      .ignoresSafeArea()
    MacFloatingSidebar(
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
      selection: .constant(.tab(.workspace)),
      onSelectStage: { _ in }
    )
  }
  .frame(width: 800, height: 600)
}
#endif
