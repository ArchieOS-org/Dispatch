//
//  iPhoneRootView.swift
//  Dispatch
//
//  Created for Dispatch Navigation Redesign
//

import SwiftUI
import SwiftData

#if os(iOS)
struct iPhoneRootView: View {

  // MARK: Internal

  var body: some View {
    TabView(selection: selectedTabBinding) {
      ForEach(AppTab.allCases.filter { $0 != .search }, id: \.self) { tab in
        NavigationStack(path: pathBinding(for: tab)) {
          rootView(for: tab)
            .appDestinations()
        }
        .tabItem {
            Label(tab.rawValue.capitalized, systemImage: iconName(for: tab))
        }
        .tag(tab)
      }
    }
  }

  // MARK: Private

  @EnvironmentObject private var appState: AppState
  
  // -- Bindings --
  
  private var selectedTabBinding: Binding<AppTab> {
    Binding(
      get: { appState.router.selectedDestination.asTab ?? .workspace },
      set: { newValue in
        Task { @MainActor in
            appState.dispatch(.userSelectedDestination(.tab(newValue)))
        }
      }
    )
  }
  
  private func pathBinding(for tab: AppTab) -> Binding<[AppRoute]> {
    Binding(
      get: { appState.router.paths[.tab(tab)] ?? [] },
      set: { newValue in
        Task { @MainActor in
          appState.dispatch(.setPath(newValue, for: .tab(tab)))
        }
      }
    )
  }
  
  // -- View Factory --
  
  private func iconName(for tab: AppTab) -> String {
    switch tab {
    case .workspace: return "checklist"
    case .properties: return "building.2"
    case .listings: return "house"
    case .realtors: return "person.2"
    case .settings: return "gearshape"
    case .search: return "magnifyingglass"
    }
  }
  
  @ViewBuilder
  private func rootView(for tab: AppTab) -> some View {
      switch tab {
      case .workspace: MyWorkspaceView()
      case .properties: PropertiesListView()
      case .listings: ListingListView()
      case .realtors: RealtorsListView()
      case .settings: SettingsView()
      case .search: MyWorkspaceView() // Fallback
      }
  }

}
#endif
