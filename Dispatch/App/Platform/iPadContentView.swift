//
//  iPadContentView.swift
//  Dispatch
//
//  iPad-specific navigation view extracted from ContentView.
//  Uses TabView with sidebarAdaptable style (iOS 18+).
//

#if os(iOS)
import SwiftUI

/// iPad navigation container with TabView using sidebarAdaptable style.
/// Extracted from ContentView to reduce complexity and enable platform-specific optimizations.
struct iPadContentView: View {

  // MARK: Internal

  /// Binding for destination-based tab selection
  let selectedDestinationBinding: Binding<SidebarDestination>

  /// Stage counts for sidebar header
  let stageCounts: [ListingStage: Int]

  /// Workspace tasks for badge counts
  let workspaceTasks: [TaskItem]

  /// Workspace activities for badge counts
  let workspaceActivities: [Activity]

  /// Active listings for badge counts
  let activeListings: [Listing]

  /// Active properties for badge counts
  let activeProperties: [Property]

  /// Active realtors for badge counts
  let activeRealtors: [User]

  /// Function to create path binding for a destination
  let pathBindingProvider: (SidebarDestination) -> Binding<[AppRoute]>

  var body: some View {
    ZStack {
      TabView(selection: selectedDestinationBinding) {
        // MARK: - Hidden stage tabs (programmatic selection only)
        // Not in a TabSection to avoid empty section header.
        // Hidden from both tabBar and sidebar; accessed via StageCardsHeader.
        ForEach(ListingStage.allCases, id: \.self) { stage in
          Tab(stage.displayName, systemImage: stage.icon, value: SidebarDestination.stage(stage)) {
            // NavigationStack structure matches main tabs for consistency.
            // Tint is applied inside StandardScreen.innerContent for content controls.
            NavigationStack(path: pathBindingProvider(.stage(stage))) {
              StagedListingsView(stage: stage)
                .appDestinations()
                .toolbar {
                  ToolbarItem(placement: .primaryAction) {
                    if appState.lensState.showFilterButton {
                      FilterMenu(audience: $appState.lensState.audience)
                    }
                  }
                }
            }
          }
          .defaultVisibility(.hidden, for: .tabBar)
          .defaultVisibility(.hidden, for: .sidebar)
        }

        // MARK: - Main tabs section
        TabSection {
          ForEach(AppTab.mainTabs) { tab in
            Tab(tab.title, systemImage: tab.icon, value: SidebarDestination.tab(tab)) {
              NavigationStack(path: pathBindingProvider(.tab(tab))) {
                tabRootView(for: tab)
                  .appDestinations()
                  .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                      if appState.lensState.showFilterButton {
                        FilterMenu(audience: $appState.lensState.audience)
                      }
                    }
                    // Stage picker button for tab-bar mode fallback
                    ToolbarItem(placement: .primaryAction) {
                      stagePickerButton
                    }
                  }
              }
            }
            .badge(badgeCount(for: tab))
          }
        }

        // MARK: - Tools section (AI and productivity features)
        TabSection("Tools") {
          Tab(
            "Listing Generator",
            systemImage: "sparkles",
            value: SidebarDestination.tab(.listingGenerator)
          ) {
            NavigationStack(path: pathBindingProvider(.tab(.listingGenerator))) {
              ListingGeneratorView()
                .appDestinations()
            }
          }
        }

        // MARK: - Settings section (separate for visual grouping)
        TabSection {
          Tab("Settings", systemImage: "gearshape", value: SidebarDestination.tab(.settings)) {
            NavigationStack {
              SettingsView()
                .appDestinations()
            }
          }
        }
      }
      .tabViewStyle(.sidebarAdaptable)
      .tabViewSidebarHeader {
        // Stage cards header - tapping uses programmatic selection (never pops)
        StageCardsHeader(
          stageCounts: stageCounts,
          onSelectStage: { stage in
            appState.dispatch(.setSelectedDestination(.stage(stage)))
          }
        )
      }
      .sheet(isPresented: $showStagePicker) {
        stagePickerSheet
      }

      // FAB overlay for iPad
      iPadFABOverlay
    }
  }

  // MARK: Private

  @EnvironmentObject private var appState: AppState

  /// Controls stage picker sheet visibility (for tab-bar mode fallback)
  @State private var showStagePicker = false

  /// Overdue count for workspace badge
  private var sidebarOverdueCount: Int {
    let startOfToday = Calendar.current.startOfDay(for: Date())
    return workspaceTasks.count(where: { ($0.dueDate ?? .distantFuture) < startOfToday })
      + workspaceActivities.count(where: { ($0.dueDate ?? .distantFuture) < startOfToday })
  }

  /// Toolbar button to open stage picker (fallback for tab-bar mode)
  @ViewBuilder
  private var stagePickerButton: some View {
    Button {
      showStagePicker = true
    } label: {
      Label("Stages", systemImage: "folder")
    }
  }

  /// Stage picker sheet for tab-bar mode fallback
  private var stagePickerSheet: some View {
    NavigationStack {
      List {
        ForEach(ListingStage.allCases, id: \.self) { stage in
          Button {
            showStagePicker = false
            appState.dispatch(.setSelectedDestination(.stage(stage)))
          } label: {
            Label {
              HStack {
                Text(stage.displayName)
                Spacer()
                if let stageCount = stageCounts[stage], stageCount > 0, stage != .done {
                  Text("\(stageCount)")
                    .foregroundStyle(.secondary)
                }
              }
            } icon: {
              Image(systemName: stage.icon)
                .foregroundStyle(stage.color)
            }
          }
          .foregroundStyle(.primary)
        }
      }
      .navigationTitle("Stages")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            showStagePicker = false
          }
        }
      }
    }
    .presentationDetents([.medium])
  }

  /// iPad floating FAB overlay with proper safe area handling
  @ViewBuilder
  private var iPadFABOverlay: some View {
    if appState.overlayState == .none {
      // ZStack so spacer doesn't block FAB taps
      ZStack(alignment: .bottomTrailing) {
        // Spacer layer - pass through all touches
        Color.clear.allowsHitTesting(false)

        // FAB - receives taps normally
        FloatingActionButton {
          appState.sheetState = .quickEntry(type: nil)
        }
        .padding(.trailing, DS.Spacing.floatingButtonMargin)
        .safeAreaPadding(.bottom, DS.Spacing.floatingButtonBottomInset)
      }
    }
  }

  /// Root view for each tab in iPad TabView.
  @ViewBuilder
  private func tabRootView(for tab: AppTab) -> some View {
    switch tab {
    case .workspace:
      MyWorkspaceView()
    case .properties:
      PropertiesListView()
    case .listings:
      ListingListView()
    case .realtors:
      RealtorsListView()
    case .settings:
      SettingsView()
    case .search:
      MyWorkspaceView() // Search is overlay, shouldn't be a tab destination
    case .listingGenerator:
      ListingGeneratorView()
    }
  }

  /// Badge count for iPad tab badges.
  private func badgeCount(for tab: AppTab) -> Int {
    switch tab {
    case .workspace:
      sidebarOverdueCount > 0 ? sidebarOverdueCount : 0
    case .listings:
      activeListings.count
    case .properties:
      activeProperties.count
    case .realtors:
      activeRealtors.count
    case .settings, .search, .listingGenerator:
      0
    }
  }

}
#endif
