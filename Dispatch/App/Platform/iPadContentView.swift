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

      // FAB and Filter floating buttons overlay for iPad
      iPadFloatingButtonsOverlay
    }
    // iPad Sheet Handling driven by AppState
    .sheet(item: appState.sheetBinding) { state in
      sheetContent(for: state)
    }
  }

  // MARK: Private

  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var overlayState: AppOverlayState

  /// Controls stage picker sheet visibility (for tab-bar mode fallback)
  @State private var showStagePicker = false

  /// Scaled icon size for FAB (base: 24pt, relative to title3)
  @ScaledMetric(relativeTo: .title3)
  private var scaledFABIconSize: CGFloat = 24

  /// Scaled icon size for filter button (base: 20pt, relative to body)
  @ScaledMetric(relativeTo: .body)
  private var scaledFilterIconSize: CGFloat = 20

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

  /// Other overlay reasons (keyboard, text input, etc.) hide all buttons
  private var shouldHideAllButtons: Bool {
    overlayState.activeReasons.contains { reason in
      switch reason {
      case .fabMenuOpen, .filterMenuOpen:
        false // Menu presentation handled by SwiftUI Menu
      case .textInput, .keyboard, .modal, .searchOverlay, .settingsScreen:
        true
      }
    }
  }

  /// iPad floating buttons overlay with both FAB and filter button
  @ViewBuilder
  private var iPadFloatingButtonsOverlay: some View {
    ZStack(alignment: .bottom) {
      // Spacer layer - pass through all touches
      Color.clear.allowsHitTesting(false)

      // Floating buttons HStack (matching GlobalFloatingButtons layout)
      HStack(alignment: .bottom) {
        // Filter Button (left) - tap cycles, long-press opens menu
        if appState.lensState.showFilterButton {
          filterButton
            .opacity(shouldHideAllButtons ? 0 : 1)
            .offset(y: shouldHideAllButtons ? 12 : 0)
            .allowsHitTesting(!shouldHideAllButtons)
            .animation(.easeInOut(duration: 0.2), value: shouldHideAllButtons)
        }

        Spacer()

        // FAB (right) - context-aware
        fabButton
          .opacity(shouldHideAllButtons ? 0 : 1)
          .offset(y: shouldHideAllButtons ? 12 : 0)
          .allowsHitTesting(!shouldHideAllButtons)
          .animation(.easeInOut(duration: 0.2), value: shouldHideAllButtons)
      }
      .padding(.horizontal, DS.Spacing.floatingButtonMargin)
      .safeAreaPadding(.bottom, DS.Spacing.floatingButtonBottomInset)
    }
  }

  /// Filter button with Menu: tap cycles filter, long-press shows all options
  @ViewBuilder
  private var filterButton: some View {
    Menu {
      ForEach(AudienceLens.allCases, id: \.self) { lens in
        Button {
          appState.lensState.audience = lens
        } label: {
          Label(lens.label, systemImage: lens.icon)
        }
      }
    } label: {
      filterButtonVisual
    } primaryAction: {
      // Tap action: cycle to next filter
      appState.lensState.audience = appState.lensState.audience.next
    }
    .sensoryFeedback(.selection, trigger: appState.lensState.audience)
    .accessibilityIdentifier("AudienceFilterButton")
    .accessibilityLabel("Filter: \(appState.lensState.audience.label)")
    .accessibilityHint("Tap to cycle, hold for options")
  }

  /// Visual representation of filter button
  private var filterButtonVisual: some View {
    ZStack {
      // 44pt glass circle, centered in 56pt hit area
      Circle()
        .fill(.ultraThinMaterial)
        .frame(width: DS.Spacing.floatingButtonSize, height: DS.Spacing.floatingButtonSize)
        .dsShadow(DS.Shadows.medium)

      // Icon
      Image(systemName: appState.lensState.audience.icon)
        .symbolRenderingMode(.monochrome)
        .foregroundStyle(
          appState.lensState.audience == .all ? .primary : appState.lensState.audience.tintColor
        )
        .font(.system(size: scaledFilterIconSize, weight: .semibold))
    }
    .frame(width: DS.Spacing.floatingButtonSizeLarge, height: DS.Spacing.floatingButtonSizeLarge)
    .contentShape(Circle())
  }

  /// Context-aware FAB: direct action for single-option contexts, Menu for multi-option
  @ViewBuilder
  private var fabButton: some View {
    switch derivedFABContext {
    case .listingList:
      // Single action: create Listing - direct tap
      FloatingActionButton {
        appState.sheetState = .addListing()
      }

    case .properties:
      // Single action: create Property - direct tap
      FloatingActionButton {
        appState.sheetState = .addProperty()
      }

    case .workspace, .listingDetail, .realtor:
      // Multi-option: SwiftUI Menu with FAB as label
      fabMenu
    }
  }

  /// FAB with integrated Menu for multi-option contexts
  private var fabMenu: some View {
    Menu {
      ForEach(fabMenuItems) { item in
        Button {
          item.action()
        } label: {
          Label(item.title, systemImage: item.icon)
        }
      }
    } label: {
      fabVisual
    }
    .accessibilityLabel("Create")
    .accessibilityHint("Opens menu with creation options")
  }

  /// Visual representation of FAB (used for multi-option contexts)
  private var fabVisual: some View {
    Circle()
      .fill(DS.Colors.accent)
      .frame(width: DS.Spacing.floatingButtonSizeLarge, height: DS.Spacing.floatingButtonSizeLarge)
      .overlay {
        Image(systemName: "plus")
          .font(.system(size: scaledFABIconSize, weight: .semibold))
          .foregroundColor(.white)
      }
      .dsShadow(DS.Shadows.elevated)
      .compositingGroup()
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
