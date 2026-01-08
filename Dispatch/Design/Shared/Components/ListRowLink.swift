//
//  ListRowLink.swift
//  Dispatch
//
//  A NavigationLink wrapper for List contexts that hides the disclosure chevron.
//

import SwiftUI

/// A NavigationLink wrapper for List contexts that hides the disclosure chevron.
///
/// Use this instead of NavigationLink when inside List/StandardList to prevent
/// SwiftUI from adding automatic disclosure indicators.
///
/// ## Features
/// - Full-row tap area via background overlay
/// - Clean VoiceOver: single accessible element (the row content)
/// - Embedded control safety: link behind content, not over it
///
/// ## Usage
/// ```swift
/// StandardList(items) { item in
///   ListRowLink(value: item) {
///     MyRowContent(item: item)
///   }
/// }
/// ```
struct ListRowLink<Value: Hashable, Content: View>: View {
  let value: Value
  @ViewBuilder let content: () -> Content

  var body: some View {
    content()
      .background {
        NavigationLink(value: value) { EmptyView() }
          .opacity(0)
      }
      .contentShape(Rectangle())
  }
}
