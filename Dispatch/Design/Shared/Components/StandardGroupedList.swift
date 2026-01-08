//
//  StandardGroupedList.swift
//  Dispatch
//
//  A grouped list component that scrolls with StandardScreen.
//

import SwiftUI

// MARK: - StandardGroupedList

/// A grouped list component that scrolls with StandardScreen.
///
/// Use this for grouped/sectioned lists that need:
/// - Non-sticky section headers
/// - Large title collapse on scroll
/// - Pull-to-search support
///
/// **Contract:** Must be used inside `StandardScreen(scroll: .automatic)`.
/// StandardScreen owns the ScrollView; this component provides LazyVStack content.
///
/// **Pull-to-Search:** Sensor is included internally. Caller must still apply
/// `.pullToSearch()` modifier to enable the full mechanism.
///
/// **Empty State:** Caller handles empty state - wrap usage in conditional.
///
/// **Separators:** Rows must render their own dividers/insets. Component adds none.
///
/// **Performance:** Groups/items should be stable and not reallocated every render.
///
/// **When to use StandardList vs StandardGroupedList:**
/// - `StandardList`: Flat lists, or when you need native List affordances (swipe, edit mode)
/// - `StandardGroupedList`: Grouped lists inside StandardScreen
struct StandardGroupedList<
  Group: Identifiable,
  Item: Identifiable,
  HeaderContent: View,
  RowContent: View
>: View {

  // MARK: Lifecycle

  init(
    _ groups: [Group],
    items: @escaping (Group) -> [Item],
    @ViewBuilder header: @escaping (Group) -> HeaderContent,
    @ViewBuilder row: @escaping (Group, Item) -> RowContent
  ) {
    self.groups = groups
    self.items = items
    self.header = header
    self.row = row
  }

  // MARK: Internal

  let groups: [Group]
  let items: (Group) -> [Item]
  @ViewBuilder let header: (Group) -> HeaderContent
  @ViewBuilder let row: (Group, Item) -> RowContent

  var body: some View {
    #if DEBUG
    let _ = assertScrollContextOnce()
    #endif

    LazyVStack(spacing: DS.Spacing.sectionSpacing) {
      // Pull-to-search sensor (caller still applies .pullToSearch() modifier)
      PullToSearchSensor()

      ForEach(groups) { group in
        VStack(alignment: .leading, spacing: 0) {
          // Non-sticky section header
          header(group)

          // Section rows
          ForEach(items(group)) { item in
            row(group, item)
          }
        }
      }
    }
    .padding(.bottom, DS.Spacing.xxl)
  }

  // MARK: Private

  @Environment(\.standardScreenScrollMode) private var scrollMode

  #if DEBUG
  /// Fire-once assertion to catch misuse during development.
  private func assertScrollContextOnce() {
    guard !StandardGroupedListAssertionState.didAssert else { return }
    StandardGroupedListAssertionState.didAssert = true

    switch scrollMode {
    case .automatic:
      break // Correct usage
    case .disabled:
      assertionFailure(
        "StandardGroupedList requires StandardScreen(scroll: .automatic). " +
          "Current mode is .disabled - large title won't collapse and headers may stick."
      )
    case .none:
      assertionFailure(
        "StandardGroupedList must be inside StandardScreen. " +
          "No scroll mode environment found - component is outside StandardScreen."
      )
    }
  }
  #endif
}

// MARK: - StandardGroupedListAssertionState

#if DEBUG
/// Fire-once state for StandardGroupedList contract assertion.
/// Ensures assertion only fires once per app lifecycle.
private enum StandardGroupedListAssertionState {
  nonisolated(unsafe) static var didAssert = false
}
#endif

// MARK: - Preview

private struct PreviewGroup: Identifiable {
  let id: String
  let name: String
  let items: [PreviewItem]
}

private struct PreviewItem: Identifiable {
  let id: String
  let title: String
}

#Preview("StandardGroupedList") {
  let groups = [
    PreviewGroup(
      id: "1",
      name: "John Smith",
      items: [
        PreviewItem(id: "1a", title: "123 Main St"),
        PreviewItem(id: "1b", title: "456 Oak Ave"),
      ]
    ),
    PreviewGroup(
      id: "2",
      name: "Jane Doe",
      items: [
        PreviewItem(id: "2a", title: "789 Pine Rd"),
        PreviewItem(id: "2b", title: "321 Elm St"),
        PreviewItem(id: "2c", title: "654 Maple Dr"),
      ]
    ),
  ]

  NavigationStack {
    StandardScreen(title: "Properties", layout: .column, scroll: .automatic) {
      StandardGroupedList(
        groups,
        items: { $0.items },
        header: { group in
          SectionHeader(group.name)
        },
        row: { _, item in
          HStack {
            Text(item.title)
              .font(DS.Typography.body)
            Spacer()
          }
          .padding(.vertical, DS.Spacing.sm)
        }
      )
    }
  }
}
