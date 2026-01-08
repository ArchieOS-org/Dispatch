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
  let count: Int
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
        .font(.system(size: 16, weight: .medium))
    }
    .tag(tab)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabelText)
  }

  // MARK: Private

  @ViewBuilder
  private var trailingContent: some View {
    if tab == .settings {
      EmptyView()
    } else if tab == .workspace, overdueCount > 0 {
      OverduePill(count: overdueCount)
    } else if count > 0 {
      Text("\(count)")
        .font(DS.Typography.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var accessibilityLabelText: String {
    var label = tab.title
    if count > 0 { label += ", \(count) open" }
    if overdueCount > 0 { label += ", \(overdueCount) overdue" }
    return label
  }
}
