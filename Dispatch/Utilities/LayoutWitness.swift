//
//  LayoutWitness.swift
//  Dispatch
//
//  Created for Dispatch Architecture Unification
//

import SwiftUI

// MARK: - Environment

struct LayoutMetrics {
    var margin: CGFloat = 0
    var maxWidth: CGFloat = 0
    var safeAreaInsets: EdgeInsets = EdgeInsets()
}

struct LayoutMetricsKey: EnvironmentKey {
    static let defaultValue = LayoutMetrics()
}

extension EnvironmentValues {
    var layoutMetrics: LayoutMetrics {
        get { self[LayoutMetricsKey.self] }
        set { self[LayoutMetricsKey.self] = newValue }
    }
}

// MARK: - Witness View

struct LayoutWitnessModifier: ViewModifier {
    @AppStorage("debug_showLayoutWitness") private var showWitness: Bool = false
    
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
}

extension View {
    func applyLayoutWitness() -> some View {
        self.modifier(LayoutWitnessModifier())
    }
}
