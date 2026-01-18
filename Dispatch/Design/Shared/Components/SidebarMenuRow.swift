//
//  SidebarMenuRow.swift
//  Dispatch
//
//  Unified menu row for iPhone, iPad, and macOS.
//  No selection styling - system handles it via List(selection:).
//

import SwiftUI

struct SidebarMenuRow: View {

  // MARK: Internal

  let tab: AppTab
  let itemCount: Int
  let overdueCount: Int

  var body: some View {
    Label {
      HStack {
        Text(tab.title)
          .font(DS.Typography.body)
        Spacer()
        trailingContent
      }
    } icon: {
      Image(systemName: tab.icon)
        .symbolRenderingMode(.hierarchical)
        .font(.system(size: iconSize, weight: .medium))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    #if os(iOS)
      .frame(minHeight: DS.Spacing.minTouchTarget)
    #endif
      .contentShape(Rectangle())
      .tag(tab)
      .accessibilityElement(children: .combine)
      .accessibilityLabel(accessibilityLabelText)
  }

  // MARK: Private

  /// Scaled icon size for Dynamic Type support (base: 16pt, relative to callout)
  @ScaledMetric(relativeTo: .callout)
  private var iconSize: CGFloat = 16

  private var accessibilityLabelText: String {
    var label = tab.title
    if itemCount > 0 { label += ", \(itemCount) open" }
    if overdueCount > 0 { label += ", \(overdueCount) overdue" }
    return label
  }

  @ViewBuilder
  private var trailingContent: some View {
    if tab == .settings {
      EmptyView()
    } else if tab == .workspace, overdueCount > 0 {
      OverduePill(count: overdueCount)
    } else if itemCount > 0 {
      Text("\(itemCount)")
        .font(DS.Typography.caption)
        .foregroundStyle(.secondary)
    }
  }

}
