//
//  PullToSearchHost.swift
//  Dispatch
//
//  Host view that renders pull-to-search indicator at screen level.
//  Used to escape navigation bar coordinate space for proper top positioning.
//

import SwiftUI

// MARK: - PullToSearchHost

/// Renders the pull-to-search indicator at screen level by reading preference values.
///
/// Wrap content that contains a scroll view with `.pullToSearchTracking()` modifier.
/// The host uses a nested overlay pattern with `ignoresSafeArea` to position
/// the indicator at the true screen top, above any navigation bar.
///
/// **Usage:**
/// ```swift
/// PullToSearchHost {
///   ScrollView {
///     content
///   }
///   .pullToSearchTracking()
/// }
/// ```
struct PullToSearchHost<Content: View>: View {

  // MARK: Lifecycle

  init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }

  // MARK: Internal

  var body: some View {
    content()
      .onPreferenceChange(PullToSearchStateKey.self) { pullState = $0 }
      #if os(iOS)
      .overlay(alignment: .top) {
        Color.clear
          .frame(height: 0)
          .overlay(alignment: .top) {
            GeometryReader { proxy in
              let safeTop = proxy.safeAreaInsets.top
              PullToSearchIndicator(state: pullState.state, progress: pullState.progress)
                .offset(y: PullToSearchLayout.screenTopOffset(pullDistance: pullState.pullDistance, safeTop: safeTop))
                .frame(maxWidth: .infinity, alignment: .top)
                .allowsHitTesting(false)
            }
            .frame(height: 0) // keeps GeometryReader from expanding
          }
          .allowsHitTesting(false)
          .ignoresSafeArea(edges: .top)
      }
      #endif
  }

  // MARK: Private

  @ViewBuilder private let content: () -> Content
  @State private var pullState = PullToSearchStateKey.Value()
}

// MARK: - Preview

#if DEBUG
#Preview("PullToSearchHost") {
  NavigationStack {
    PullToSearchHost {
      ScrollView {
        VStack(spacing: 16) {
          ForEach(0 ..< 20) { i in
            Text("Row \(i)")
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding()
              .background(Color.gray.opacity(0.1))
              .cornerRadius(8)
          }
        }
        .padding()
      }
      .pullToSearchTracking()
    }
    .navigationTitle("Test Screen")
    #if os(iOS)
    .navigationBarTitleDisplayMode(.large)
    #endif
  }
}
#endif
