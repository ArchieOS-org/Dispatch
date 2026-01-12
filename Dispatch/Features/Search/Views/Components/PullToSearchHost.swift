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
        // Use device safe area (from window), not view safe area which may include nav bar
        let safeTop = Self.deviceSafeAreaTop
        Color.clear
          .overlay(alignment: .top) {
            PullToSearchIndicator(state: pullState.state, progress: pullState.progress)
              // iconOffset gives 1:1 movement with pullDistance
              .offset(y: safeTop + PullToSearchLayout.iconOffset(pullDistance: pullState.pullDistance))
              .frame(maxWidth: .infinity, alignment: .top)
              .allowsHitTesting(false)
          }
          // ignoresSafeArea so indicator can extend above safe area (behind Dynamic Island)
          .ignoresSafeArea(edges: .top)
          .frame(height: 0)
          .allowsHitTesting(false)
      }
      #endif
  }

  // MARK: Private

  #if os(iOS)
  /// Device safe area top (Dynamic Island/notch), not view-adjusted safe area.
  /// View safe area may include navigation bar height, which we don't want.
  private static var deviceSafeAreaTop: CGFloat {
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let window = windowScene.windows.first {
      return window.safeAreaInsets.top
    }
    return 59 // Fallback for Dynamic Island devices
  }
  #endif

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
