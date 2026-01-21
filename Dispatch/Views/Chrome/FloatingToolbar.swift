//
//  FloatingToolbar.swift
//  Dispatch
//
//  Created for Dispatch Navigation Redesign
//

import SwiftUI

/// A floating toolbar that sits at the top of the content area.
/// Used on macOS and iPadOS to provide a unified action area without a traditional window toolbar.
struct FloatingToolbar: View {

  // MARK: Lifecycle

  init(title: String? = nil, content: @escaping () -> any View) {
    self.title = title
    self.actions = AnyView(content())
  }
  
  init(title: String? = nil) {
    self.title = title
    self.actions = AnyView(EmptyView())
  }

  // MARK: Internal

  var body: some View {
    HStack(spacing: DS.Spacing.md) {
      if let title {
        Text(title)
          .font(DS.Typography.title3)
          .foregroundColor(DS.Colors.Text.primary)
      }

      Spacer()

      actions
    }
    .padding(.horizontal, DS.Spacing.lg)
    .padding(.vertical, DS.Spacing.sm)
    .background(.thinMaterial)
    .clipShape(Capsule())
    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    .padding(.top, DS.Spacing.md)
    .padding(.horizontal, DS.Spacing.lg)
  }

  // MARK: Private

  private let title: String?
  private let actions: AnyView

}

#Preview {
  ZStack(alignment: .top) {
    Color.blue.opacity(0.1).ignoresSafeArea()
    
    FloatingToolbar(title: "Listings") {
      HStack {
        Button(action: {}) {
          Image(systemName: "magnifyingglass")
        }
        Button(action: {}) {
            Image(systemName: "plus")
        }
      }
    }
  }
}
