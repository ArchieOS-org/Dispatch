//
//  LayoutWitness.swift
//  Dispatch
//
//  Created for Dispatch Architecture Unification
//

import SwiftUI

// MARK: - LayoutMetrics

struct LayoutMetrics {
  var margin: CGFloat = 0
  var maxWidth: CGFloat = 0
  var safeAreaInsets = EdgeInsets()
}

extension EnvironmentValues {
  @Entry var layoutMetrics = LayoutMetrics()
}

// MARK: - LayoutWitnessModifier

struct LayoutWitnessModifier: ViewModifier {

  // MARK: Internal

  func body(content: Content) -> some View {
    content.overlay(
      Group {
        if showWitness {
          VStack {
            Spacer()
            HStack {
              Text("LayoutWitness")
                .font(.caption2)
                .bold()
              Divider()
              Text("Margin: \(DS.Spacing.Layout.pageMargin)")
                .font(.caption2)
              Divider()
              Text("MaxW: \(DS.Spacing.Layout.maxContentWidth)")
                .font(.caption2)
            }
            .padding(4)
            .background(Color.red.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(4)
            .padding()
          }
        }
      }
    )
  }

  // MARK: Private

  @AppStorage("debug_showLayoutWitness") private var showWitness = false

}

extension View {
  func applyLayoutWitness() -> some View {
    modifier(LayoutWitnessModifier())
  }
}
