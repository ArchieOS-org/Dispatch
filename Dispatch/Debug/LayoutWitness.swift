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
                .font(DS.Typography.captionSecondary)
                .bold()
              Divider()
              Text("Margin: \(DS.Spacing.Layout.pageMargin)")
                .font(DS.Typography.captionSecondary)
              Divider()
              Text("MaxW: \(DS.Spacing.Layout.maxContentWidth)")
                .font(DS.Typography.captionSecondary)
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
