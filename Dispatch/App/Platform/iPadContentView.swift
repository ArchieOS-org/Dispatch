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

  /// All users for sheet
  let users: [User]

  /// Current user ID for sheets
  let currentUserId: UUID

  /// Function to create path binding for a destination
  let pathBindingProvider: (SidebarDestination) -> Binding<[AppRoute]>

  /// Callback to request sync after save
  let onRequestSync: () -> Void

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
                .fabContext(.listingList)
                .appDestinations()
                .toolbar {
                  // Removed FilterMenu toolbar button
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
                    // Removed FilterMenu toolbar button
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

      // Custom FAB menu overlay with iOS 26 effects (liquid glass + spring animation)
      FABMenuOverlay(
        isPresented: $showFABMenu,
        items: fabMenuItems
      )
      .opacity(shouldHideFABCombined ? 0 : 1)
      .offset(y: shouldHideFABCombined ? 12 : 0)
      .allowsHitTesting(!shouldHideFABCombined)
      .animation(.easeInOut(duration: 0.2), value: shouldHideFAB)
      .animation(.easeInOut(duration: 0.2), value: shouldHideAllButtons)

      // Floating filter menu overlay (tap cycles, long-press opens menu)
      if appState.lensState.showFilterButton {
        FilterMenuOverlay(
          isPresented: $showFilterMenu,
          audience: $appState.lensState.audience
        )
        .opacity(shouldHideFilterCombined ? 0 : 1)
        .offset(y: shouldHideFilterCombined ? 12 : 0)
        .allowsHitTesting(!shouldHideFilterCombined)
        .animation(.easeInOut(duration: 0.2), value: shouldHideFilter)
        .animation(.easeInOut(duration: 0.2), value: shouldHideAllButtons)
      }
    }
    // iPad Sheet Handling driven by AppState
    .sheet(item: appState.sheetBinding) { state in
      sheetContent(for: state)
    }
    .onChange(of: showFABMenu) { _, isPresented in
      if isPresented {
        overlayState.hide(reason: .fabMenuOpen)
      } else {
        overlayState.show(reason: .fabMenuOpen)
      }
    }
    .onChange(of: showFilterMenu) { _, isPresented in
      if isPresented {
        overlayState.hide(reason: .filterMenuOpen)
      } else {
        overlayState.show(reason: .filterMenuOpen)
      }
    }
  }

  // MARK: Private

  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var overlayState: AppOverlayState

  /// Controls stage picker sheet visibility (for tab-bar mode fallback)
  @State private var showStagePicker = false

  /// Controls FAB menu presentation
  @State private var showFABMenu = false

  /// Controls filter menu presentation
  @State private var showFilterMenu = false

  /// Derived FAB context from router state (environment doesn't propagate to overlay sibling)
  private var derivedFABContext: FABContext {
    switch appState.router.selectedDestination {
    case .tab(.workspace):
      .workspace
    case .tab(.listings):
      .listingList
    case .tab(.properties):
      .properties
    case .tab(.realtors):
      .workspace // Realtor list uses workspace context
    case .stage:
      .listingList
    default:
      .workspace
    }
  }

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

  /// FAB hides when FAB menu is open
  private var shouldHideFAB: Bool {
    overlayState.isReasonActive(.fabMenuOpen)
  }

  /// Filter button hides when filter menu is open
  private var shouldHideFilter: Bool {
    overlayState.isReasonActive(.filterMenuOpen)
  }

  /// Other overlay reasons (keyboard, text input, etc.) hide all buttons
  private var shouldHideAllButtons: Bool {
    overlayState.activeReasons.contains { reason in
      switch reason {
      case .fabMenuOpen, .filterMenuOpen:
        false // FAB and filter handled independently
      case .textInput, .keyboard, .modal, .searchOverlay, .settingsScreen:
        true
      }
    }
  }

  /// Combined: hide FAB if its menu is open OR global hide reasons active
  private var shouldHideFABCombined: Bool {
    shouldHideFAB || shouldHideAllButtons
  }

  /// Combined: hide filter if its menu is open OR global hide reasons active
  private var shouldHideFilterCombined: Bool {
    shouldHideFilter || shouldHideAllButtons
  }

  /// iPad floating FAB overlay with proper safe area handling
  @ViewBuilder
  private var iPadFABOverlay: some View {
    // ZStack so spacer doesn't block FAB taps
    ZStack(alignment: .bottomTrailing) {
      // Spacer layer - pass through all touches
      Color.clear.allowsHitTesting(false)

      // FAB area
      // - Single-action contexts: show the plain FAB here
      // - Multi-option contexts: the menu button is rendered by `FABMenuOverlay` (so we must NOT render a second FAB)
      Group {
        switch derivedFABContext {
        case .listingList:
          FloatingActionButton {
            appState.sheetState = .addListing()
          }

        case .properties:
          FloatingActionButton {
            appState.sheetState = .addProperty()
          }

        default:
          // Keep layout stable while the menu-backed FAB is shown by the separate overlay.
          Color.clear
            .frame(
              width: DS.Spacing.floatingButtonSizeLarge,
              height: DS.Spacing.floatingButtonSizeLarge
            )
        }
      }
      .padding(.trailing, DS.Spacing.floatingButtonMargin)
      .safeAreaPadding(.bottom, DS.Spacing.floatingButtonBottomInset)
      .opacity(shouldHideFABCombined ? 0 : 1)
      .offset(y: shouldHideFABCombined ? 12 : 0)
      .allowsHitTesting(!shouldHideFABCombined)
      .animation(.easeInOut(duration: 0.2), value: shouldHideFAB)
      .animation(.easeInOut(duration: 0.2), value: shouldHideAllButtons)
    }
  }

  /// Context-aware FAB menu items based on current context
  private var fabMenuItems: [FABMenuItem] {
    switch derivedFABContext {
    case .workspace:
      [
        FABMenuItem(title: "New Task", icon: DS.Icons.Entity.task) {
          appState.sheetState = .quickEntry(type: .task)
        },
        FABMenuItem(title: "New Activity", icon: DS.Icons.Entity.activity) {
          appState.sheetState = .quickEntry(type: .activity)
        },
        FABMenuItem(title: "New Listing", icon: DS.Icons.Entity.listing) {
          appState.sheetState = .addListing()
        }
      ]

    case .listingDetail(let listingId):
      [
        FABMenuItem(title: "New Task", icon: DS.Icons.Entity.task) {
          appState.sheetState = .quickEntry(type: .task, preSelectedListingId: listingId)
        },
        FABMenuItem(title: "New Activity", icon: DS.Icons.Entity.activity) {
          appState.sheetState = .quickEntry(type: .activity, preSelectedListingId: listingId)
        }
      ]

    case .realtor(let realtorId):
      [
        FABMenuItem(title: "New Property", icon: DS.Icons.Entity.property) {
          appState.sheetState = .addProperty(forRealtorId: realtorId)
        },
        FABMenuItem(title: "New Listing", icon: DS.Icons.Entity.listing) {
          appState.sheetState = .addListing(forRealtorId: realtorId)
        }
      ]

    case .listingList, .properties:
      // Single-action contexts don't use the menu
      []
    }
  }

  // MARK: - Sheet Content

  @ViewBuilder
  private func sheetContent(for state: AppState.SheetState) -> some View {
    switch state {
    case .quickEntry(let type, let preSelectedListingId):
      QuickEntrySheet(
        defaultItemType: type ?? .task,
        currentUserId: currentUserId,
        listings: activeListings,
        availableUsers: users,
        preSelectedListingId: preSelectedListingId,
        onSave: { onRequestSync() }
      )

    case .addListing:
      AddListingSheet(
        currentUserId: currentUserId,
        onSave: { onRequestSync() }
      )
      // Note: AddListingSheet doesn't yet support forRealtorId - future enhancement

    case .addRealtor:
      EditRealtorSheet()

    case .addProperty(let forRealtorId):
      AddPropertySheet(
        currentUserId: currentUserId,
        forRealtorId: forRealtorId,
        onSave: { onRequestSync() }
      )

    case .none:
      EmptyView()
    }
  }

  /// Root view for each tab in iPad TabView.
  /// Sets FABContext for context-aware FAB behavior.
  @ViewBuilder
  private func tabRootView(for tab: AppTab) -> some View {
    switch tab {
    case .workspace:
      MyWorkspaceView()
        .fabContext(.workspace)

    case .properties:
      PropertiesListView()
        .fabContext(.properties)

    case .listings:
      ListingListView()
        .fabContext(.listingList)

    case .realtors:
      RealtorsListView()
        .fabContext(.workspace) // Realtor list uses workspace context (no specific realtor)

    case .settings:
      SettingsView()
        .fabContext(.workspace)

    case .search:
      MyWorkspaceView() // Search is overlay, shouldn't be a tab destination
        .fabContext(.workspace)
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
    case .settings, .search:
      0
    }
  }

}
#endif
