//
//  ListRowLink.swift
//  Dispatch
//
//  A NavigationLink wrapper that hides the disclosure chevron in List contexts
//  and works correctly in LazyVStack contexts (StandardGroupedList).
//

import SwiftUI

/// A NavigationLink wrapper that works in both List and LazyVStack contexts.
///
/// **In List contexts** (StandardList, native List): Uses background overlay to hide chevron.
/// **In LazyVStack contexts** (StandardGroupedList): Uses NavigationLink as outer container.
///
/// The component automatically detects the context via `standardScreenScrollMode` environment.
///
/// ## Features
/// - Full-row tap area
/// - No disclosure chevron in any context
/// - Clean VoiceOver: single accessible element (the row content)
///
/// ## Usage
/// ```swift
/// // In StandardList (List context)
/// StandardList(items) { item in
///   ListRowLink(value: item) {
///     MyRowContent(item: item)
///   }
/// }
///
/// // In StandardGroupedList (LazyVStack context)
/// StandardGroupedList(groups, items: { ... }) { group, item in
///   ListRowLink(value: item) {
///     MyRowContent(item: item)
///   }
/// }
/// ```
struct ListRowLink<Value: Hashable, Content: View>: View {
  let value: Value
  @ViewBuilder let content: () -> Content

  @Environment(\.standardScreenScrollMode) private var scrollMode

  var body: some View {
    // In LazyVStack contexts (StandardGroupedList with scroll: .automatic),
    // use NavigationLink as outer container - taps hit it directly.
    // In List contexts (scroll: .disabled or outside StandardScreen),
    // use background trick to hide the disclosure chevron.
    if scrollMode == .automatic {
      // LazyVStack context: NavigationLink outer, no chevron added
      NavigationLink(value: value) {
        content()
      }
      .buttonStyle(.plain)
      .contentShape(Rectangle())
    } else {
      // List context: background trick hides chevron
      content()
        .background {
          NavigationLink(value: value) { EmptyView() }
            .opacity(0)
        }
        .contentShape(Rectangle())
    }
  }
}
