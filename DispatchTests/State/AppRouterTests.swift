//
//  AppRouterTests.swift
//  DispatchTests
//
//  Comprehensive tests for AppRouter navigation state management.
//  Tests: SidebarDestination, iPad/macOS navigation, iPhone navigation, route cleanup.
//

import Foundation
import Testing
@testable import DispatchApp

// MARK: - SidebarDestinationTests

struct SidebarDestinationTests {

  // MARK: - asTab Tests

  @Test("asTab returns tab for .tab case")
  func testAsTabReturnsTabForTabCase() {
    let destination = SidebarDestination.tab(.workspace)
    #expect(destination.asTab == .workspace)
  }

  @Test("asTab returns nil for .stage case")
  func testAsTabReturnsNilForStageCase() {
    let destination = SidebarDestination.stage(.pending)
    #expect(destination.asTab == nil)
  }

  @Test("asTab returns correct tab for all tab cases")
  func testAsTabReturnsCorrectTabForAllCases() {
    for tab in AppTab.allCases {
      let destination = SidebarDestination.tab(tab)
      #expect(destination.asTab == tab)
    }
  }

  // MARK: - isStage Tests

  @Test("isStage returns true only for .stage case")
  func testIsStageReturnsTrueForStageCase() {
    let stageDestination = SidebarDestination.stage(.live)
    #expect(stageDestination.isStage == true)
  }

  @Test("isStage returns false for .tab case")
  func testIsStageReturnsFalseForTabCase() {
    let tabDestination = SidebarDestination.tab(.listings)
    #expect(tabDestination.isStage == false)
  }

  @Test("isStage returns true for all stage cases")
  func testIsStageReturnsTrueForAllStageCases() {
    for stage in ListingStage.allCases {
      let destination = SidebarDestination.stage(stage)
      #expect(destination.isStage == true)
    }
  }

  // MARK: - asStage Tests

  @Test("asStage returns stage for .stage case")
  func testAsStageReturnsStageForStageCase() {
    let destination = SidebarDestination.stage(.workingOn)
    #expect(destination.asStage == .workingOn)
  }

  @Test("asStage returns nil for .tab case")
  func testAsStageReturnsNilForTabCase() {
    let destination = SidebarDestination.tab(.properties)
    #expect(destination.asStage == nil)
  }

  @Test("asStage returns correct stage for all stage cases")
  func testAsStageReturnsCorrectStageForAllCases() {
    for stage in ListingStage.allCases {
      let destination = SidebarDestination.stage(stage)
      #expect(destination.asStage == stage)
    }
  }

  // MARK: - Hashable Tests

  @Test("SidebarDestination equality works for same tab")
  func testEqualityForSameTab() {
    let dest1 = SidebarDestination.tab(.workspace)
    let dest2 = SidebarDestination.tab(.workspace)
    #expect(dest1 == dest2)
  }

  @Test("SidebarDestination equality works for same stage")
  func testEqualityForSameStage() {
    let dest1 = SidebarDestination.stage(.pending)
    let dest2 = SidebarDestination.stage(.pending)
    #expect(dest1 == dest2)
  }

  @Test("SidebarDestination inequality for different tabs")
  func testInequalityForDifferentTabs() {
    let dest1 = SidebarDestination.tab(.workspace)
    let dest2 = SidebarDestination.tab(.listings)
    #expect(dest1 != dest2)
  }

  @Test("SidebarDestination inequality for different stages")
  func testInequalityForDifferentStages() {
    let dest1 = SidebarDestination.stage(.pending)
    let dest2 = SidebarDestination.stage(.live)
    #expect(dest1 != dest2)
  }

  @Test("SidebarDestination inequality between tab and stage")
  func testInequalityBetweenTabAndStage() {
    let tabDest = SidebarDestination.tab(.listings)
    let stageDest = SidebarDestination.stage(.pending)
    #expect(tabDest != stageDest)
  }
}

// MARK: - AppRouterIPadMacNavigationTests

struct AppRouterIPadMacNavigationTests {

  // MARK: - navigate(to:) Tests

  @Test("navigate(to:) appends to current destination path")
  func testNavigateAppendsToCurrentPath() {
    var router = AppRouter()
    let route = AppRoute.listing(UUID())

    router.navigate(to: route)

    let currentPath = router.paths[router.selectedDestination] ?? []
    #expect(currentPath.count == 1)
  }

  @Test("navigate(to:) builds correct path stack with multiple navigations")
  func testNavigateBuildsCorrectPathStack() {
    var router = AppRouter()
    let id1 = UUID()
    let id2 = UUID()
    let id3 = UUID()

    router.navigate(to: .listing(id1))
    router.navigate(to: .property(id2))
    router.navigate(to: .realtor(id3))

    let currentPath = router.paths[router.selectedDestination] ?? []
    #expect(currentPath.count == 3)
    #expect(currentPath[0] == .listing(id1))
    #expect(currentPath[1] == .property(id2))
    #expect(currentPath[2] == .realtor(id3))
  }

  // MARK: - navigate(to:on:) Tests

  @Test("navigate(to:on:) appends to specified destination path")
  func testNavigateOnDestinationAppendsToSpecifiedPath() {
    var router = AppRouter()
    router.selectedDestination = .tab(.workspace)
    let route = AppRoute.listing(UUID())

    router.navigate(to: route, on: .tab(.listings))

    let listingsPath = router.paths[.tab(.listings)] ?? []
    #expect(listingsPath.count == 1)

    // Current destination path should be empty
    let workspacePath = router.paths[.tab(.workspace)] ?? []
    #expect(workspacePath.isEmpty)
  }

  @Test("navigate(to:on:) with nil destination uses current destination")
  func testNavigateOnNilDestinationUsesCurrentDestination() {
    var router = AppRouter()
    router.selectedDestination = .tab(.properties)
    let route = AppRoute.property(UUID())

    router.navigate(to: route, on: nil)

    let propertiesPath = router.paths[.tab(.properties)] ?? []
    #expect(propertiesPath.count == 1)
  }

  // MARK: - popToRoot() Tests

  @Test("popToRoot() clears current destination path")
  func testPopToRootClearsCurrentPath() {
    var router = AppRouter()
    router.navigate(to: .listing(UUID()))
    router.navigate(to: .property(UUID()))

    router.popToRoot()

    let currentPath = router.paths[router.selectedDestination] ?? []
    #expect(currentPath.isEmpty)
  }

  @Test("popToRoot() is idempotent on empty path")
  func testPopToRootIsIdempotent() {
    var router = AppRouter()
    // Path is already empty, this should be a no-op
    router.popToRoot()
    router.popToRoot()
    router.popToRoot()

    let currentPath = router.paths[router.selectedDestination] ?? []
    #expect(currentPath.isEmpty)
  }

  // MARK: - popToRoot(for:) Tests

  @Test("popToRoot(for:) clears specified destination path")
  func testPopToRootForClearsSpecifiedPath() {
    var router = AppRouter()
    router.navigate(to: .listing(UUID()), on: .tab(.listings))
    router.navigate(to: .property(UUID()), on: .tab(.properties))

    router.popToRoot(for: .tab(.listings))

    let listingsPath = router.paths[.tab(.listings)] ?? []
    #expect(listingsPath.isEmpty)

    // Properties path should be unchanged
    let propertiesPath = router.paths[.tab(.properties)] ?? []
    #expect(propertiesPath.count == 1)
  }

  @Test("popToRoot(for:) with nil uses current destination")
  func testPopToRootForNilUsesCurrentDestination() {
    var router = AppRouter()
    router.navigate(to: .listing(UUID()))

    router.popToRoot(for: nil)

    let currentPath = router.paths[router.selectedDestination] ?? []
    #expect(currentPath.isEmpty)
  }

  // MARK: - Per-Destination Path Independence Tests

  @Test("per-destination paths are independent")
  func testPerDestinationPathsAreIndependent() {
    var router = AppRouter()

    // Navigate on different destinations
    router.navigate(to: .listing(UUID()), on: .tab(.workspace))
    router.navigate(to: .listing(UUID()), on: .tab(.workspace))
    router.navigate(to: .property(UUID()), on: .tab(.listings))
    router.navigate(to: .realtor(UUID()), on: .stage(.pending))

    let workspacePath = router.paths[.tab(.workspace)] ?? []
    let listingsPath = router.paths[.tab(.listings)] ?? []
    let pendingPath = router.paths[.stage(.pending)] ?? []

    #expect(workspacePath.count == 2)
    #expect(listingsPath.count == 1)
    #expect(pendingPath.count == 1)
  }

  @Test("clearing one destination does not affect others")
  func testClearingOneDestinationDoesNotAffectOthers() {
    var router = AppRouter()
    router.navigate(to: .listing(UUID()), on: .tab(.workspace))
    router.navigate(to: .property(UUID()), on: .tab(.listings))
    router.navigate(to: .realtor(UUID()), on: .tab(.realtors))

    router.popToRoot(for: .tab(.listings))

    let workspacePath = router.paths[.tab(.workspace)] ?? []
    let listingsPath = router.paths[.tab(.listings)] ?? []
    let realtorsPath = router.paths[.tab(.realtors)] ?? []

    #expect(workspacePath.count == 1)
    #expect(listingsPath.isEmpty)
    #expect(realtorsPath.count == 1)
  }
}

// MARK: - AppRouterUserVsProgrammaticSelectionTests

struct AppRouterUserVsProgrammaticSelectionTests {

  // MARK: - userSelectDestination Tests

  @Test("userSelectDestination on same destination pops to root")
  func testUserSelectDestinationOnSameDestinationPopsToRoot() {
    var router = AppRouter()
    router.selectedDestination = .tab(.workspace)
    router.navigate(to: .listing(UUID()))
    router.navigate(to: .property(UUID()))

    router.userSelectDestination(.tab(.workspace))

    let currentPath = router.paths[.tab(.workspace)] ?? []
    #expect(currentPath.isEmpty)
    #expect(router.selectedDestination == .tab(.workspace))
  }

  @Test("userSelectDestination on different destination switches AND pops new destination")
  func testUserSelectDestinationOnDifferentDestinationSwitchesAndPops() {
    var router = AppRouter()
    router.selectedDestination = .tab(.workspace)
    // Pre-populate the listings path
    router.navigate(to: .listing(UUID()), on: .tab(.listings))

    router.userSelectDestination(.tab(.listings))

    // Should switch to listings
    #expect(router.selectedDestination == .tab(.listings))
    // Listings path should be cleared (user tap always shows root)
    let listingsPath = router.paths[.tab(.listings)] ?? []
    #expect(listingsPath.isEmpty)
  }

  @Test("userSelectDestination preserves other destination paths")
  func testUserSelectDestinationPreservesOtherPaths() {
    var router = AppRouter()
    router.selectedDestination = .tab(.workspace)
    router.navigate(to: .listing(UUID()), on: .tab(.workspace))
    router.navigate(to: .property(UUID()), on: .tab(.properties))

    router.userSelectDestination(.tab(.listings))

    // Workspace path should be preserved
    let workspacePath = router.paths[.tab(.workspace)] ?? []
    #expect(workspacePath.count == 1)

    // Properties path should be preserved
    let propertiesPath = router.paths[.tab(.properties)] ?? []
    #expect(propertiesPath.count == 1)
  }

  // MARK: - setSelectedDestination Tests

  @Test("setSelectedDestination switches WITHOUT popping")
  func testSetSelectedDestinationSwitchesWithoutPopping() {
    var router = AppRouter()
    router.selectedDestination = .tab(.workspace)
    // Pre-populate the listings path
    router.navigate(to: .listing(UUID()), on: .tab(.listings))
    router.navigate(to: .property(UUID()), on: .tab(.listings))

    router.setSelectedDestination(.tab(.listings))

    // Should switch to listings
    #expect(router.selectedDestination == .tab(.listings))
    // Listings path should be PRESERVED (programmatic navigation)
    let listingsPath = router.paths[.tab(.listings)] ?? []
    #expect(listingsPath.count == 2)
  }

  @Test("setSelectedDestination to same destination is no-op")
  func testSetSelectedDestinationToSameDestinationIsNoOp() {
    var router = AppRouter()
    router.selectedDestination = .tab(.workspace)
    router.navigate(to: .listing(UUID()))

    router.setSelectedDestination(.tab(.workspace))

    #expect(router.selectedDestination == .tab(.workspace))
    let currentPath = router.paths[.tab(.workspace)] ?? []
    #expect(currentPath.count == 1)
  }

  @Test("setSelectedDestination works with stage destinations")
  func testSetSelectedDestinationWorksWithStages() {
    var router = AppRouter()
    router.selectedDestination = .tab(.workspace)

    router.setSelectedDestination(.stage(.pending))

    #expect(router.selectedDestination == .stage(.pending))
  }
}

// MARK: - AppRouterIPhoneNavigationTests

struct AppRouterIPhoneNavigationTests {

  // MARK: - phoneNavigate Tests

  @Test("phoneNavigate appends to phonePath")
  func testPhoneNavigateAppendsToPath() {
    var router = AppRouter()
    let route = AppRoute.listing(UUID())

    router.phoneNavigate(to: route)

    #expect(router.phonePath.count == 1)
  }

  @Test("phoneNavigate builds correct path stack")
  func testPhoneNavigateBuildsCorrectStack() {
    var router = AppRouter()
    let id1 = UUID()
    let id2 = UUID()
    let id3 = UUID()

    router.phoneNavigate(to: .listing(id1))
    router.phoneNavigate(to: .property(id2))
    router.phoneNavigate(to: .realtor(id3))

    #expect(router.phonePath.count == 3)
    #expect(router.phonePath[0] == .listing(id1))
    #expect(router.phonePath[1] == .property(id2))
    #expect(router.phonePath[2] == .realtor(id3))
  }

  // MARK: - phonePopToRoot Tests

  @Test("phonePopToRoot clears phonePath")
  func testPhonePopToRootClearsPath() {
    var router = AppRouter()
    router.phoneNavigate(to: .listing(UUID()))
    router.phoneNavigate(to: .property(UUID()))

    router.phonePopToRoot()

    #expect(router.phonePath.isEmpty)
  }

  @Test("phonePopToRoot is idempotent on empty path")
  func testPhonePopToRootIsIdempotent() {
    var router = AppRouter()
    // Path is already empty
    router.phonePopToRoot()
    router.phonePopToRoot()
    router.phonePopToRoot()

    #expect(router.phonePath.isEmpty)
  }

  // MARK: - iPhone vs iPad Independence Tests

  @Test("phonePath is independent from destination paths")
  func testPhonePathIsIndependentFromDestinationPaths() {
    var router = AppRouter()

    router.phoneNavigate(to: .listing(UUID()))
    router.phoneNavigate(to: .property(UUID()))
    router.navigate(to: .realtor(UUID()))

    #expect(router.phonePath.count == 2)
    let currentPath = router.paths[router.selectedDestination] ?? []
    #expect(currentPath.count == 1)
  }
}

// MARK: - AppRouterRouteCleanupTests

struct AppRouterRouteCleanupTests {

  // MARK: - removeRoute Tests

  @Test("removeRoute removes from phonePath")
  func testRemoveRouteRemovesFromPhonePath() {
    var router = AppRouter()
    let id = UUID()
    let route = AppRoute.listing(id)

    router.phoneNavigate(to: route)
    router.phoneNavigate(to: .property(UUID()))

    router.removeRoute(route)

    #expect(router.phonePath.count == 1)
    #expect(!router.phonePath.contains(route))
  }

  @Test("removeRoute removes from all destination paths")
  func testRemoveRouteRemovesFromAllDestinationPaths() {
    var router = AppRouter()
    let id = UUID()
    let route = AppRoute.listing(id)

    router.navigate(to: route, on: .tab(.workspace))
    router.navigate(to: route, on: .tab(.listings))
    router.navigate(to: route, on: .stage(.pending))

    router.removeRoute(route)

    let workspacePath = router.paths[.tab(.workspace)] ?? []
    let listingsPath = router.paths[.tab(.listings)] ?? []
    let pendingPath = router.paths[.stage(.pending)] ?? []

    #expect(!workspacePath.contains(route))
    #expect(!listingsPath.contains(route))
    #expect(!pendingPath.contains(route))
  }

  @Test("removeRoute handles route not present (no-op)")
  func testRemoveRouteHandlesRouteNotPresent() {
    var router = AppRouter()
    let presentRoute = AppRoute.listing(UUID())
    let absentRoute = AppRoute.property(UUID())

    router.phoneNavigate(to: presentRoute)
    router.navigate(to: presentRoute)

    // Should not crash or change anything
    router.removeRoute(absentRoute)

    #expect(router.phonePath.count == 1)
    let currentPath = router.paths[router.selectedDestination] ?? []
    #expect(currentPath.count == 1)
  }

  @Test("removeRoute removes all occurrences of route from a single path")
  func testRemoveRouteRemovesAllOccurrences() {
    var router = AppRouter()
    let id = UUID()
    let route = AppRoute.listing(id)

    // Add same route multiple times
    router.phoneNavigate(to: route)
    router.phoneNavigate(to: .property(UUID()))
    router.phoneNavigate(to: route)

    router.removeRoute(route)

    #expect(router.phonePath.count == 1)
    #expect(!router.phonePath.contains(route))
  }
}

// MARK: - AppRouterLegacyTabMethodsTests

struct AppRouterLegacyTabMethodsTests {

  // MARK: - userSelectTab Tests

  @Test("userSelectTab maps to userSelectDestination(.tab(...))")
  func testUserSelectTabMapsToUserSelectDestination() {
    var router = AppRouter()
    router.selectedDestination = .tab(.workspace)
    router.navigate(to: .listing(UUID()), on: .tab(.listings))

    router.userSelectTab(.listings)

    // Should behave like userSelectDestination
    #expect(router.selectedDestination == .tab(.listings))
    let listingsPath = router.paths[.tab(.listings)] ?? []
    #expect(listingsPath.isEmpty) // User select pops to root
  }

  @Test("userSelectTab on same tab pops to root")
  func testUserSelectTabOnSameTabPopsToRoot() {
    var router = AppRouter()
    router.selectedDestination = .tab(.workspace)
    router.navigate(to: .listing(UUID()))

    router.userSelectTab(.workspace)

    let workspacePath = router.paths[.tab(.workspace)] ?? []
    #expect(workspacePath.isEmpty)
  }

  // MARK: - setSelectedTab Tests

  @Test("setSelectedTab maps to setSelectedDestination(.tab(...))")
  func testSetSelectedTabMapsToSetSelectedDestination() {
    var router = AppRouter()
    router.selectedDestination = .tab(.workspace)
    router.navigate(to: .listing(UUID()), on: .tab(.listings))
    router.navigate(to: .property(UUID()), on: .tab(.listings))

    router.setSelectedTab(.listings)

    // Should behave like setSelectedDestination (no popping)
    #expect(router.selectedDestination == .tab(.listings))
    let listingsPath = router.paths[.tab(.listings)] ?? []
    #expect(listingsPath.count == 2) // Path preserved
  }

  // MARK: - selectedTab Computed Property Tests

  @Test("selectedTab returns correct tab when destination is a tab")
  func testSelectedTabReturnsCorrectTabForTabDestination() {
    var router = AppRouter()
    router.selectedDestination = .tab(.properties)

    #expect(router.selectedTab == .properties)
  }

  @Test("selectedTab returns .workspace when destination is a stage")
  func testSelectedTabReturnsWorkspaceForStageDestination() {
    var router = AppRouter()
    router.selectedDestination = .stage(.pending)

    #expect(router.selectedTab == .workspace)
  }

  @Test("selectedTab returns .workspace for all stage destinations")
  func testSelectedTabReturnsWorkspaceForAllStages() {
    var router = AppRouter()

    for stage in ListingStage.allCases {
      router.selectedDestination = .stage(stage)
      #expect(router.selectedTab == .workspace)
    }
  }
}

// MARK: - AppRouteHashabilityTests

struct AppRouteHashabilityTests {

  // MARK: - Equality Tests

  @Test("AppRoute cases with same UUID are equal")
  func testAppRouteCasesWithSameUUIDAreEqual() {
    let id = UUID()

    #expect(AppRoute.listing(id) == AppRoute.listing(id))
    #expect(AppRoute.property(id) == AppRoute.property(id))
    #expect(AppRoute.realtor(id) == AppRoute.realtor(id))
    #expect(AppRoute.listingType(id) == AppRoute.listingType(id))
  }

  @Test("Different route types with same UUID are NOT equal")
  func testDifferentRouteTypesWithSameUUIDAreNotEqual() {
    let id = UUID()

    #expect(AppRoute.listing(id) != AppRoute.property(id))
    #expect(AppRoute.property(id) != AppRoute.realtor(id))
    #expect(AppRoute.realtor(id) != AppRoute.listingType(id))
  }

  @Test("Same route type with different UUIDs are NOT equal")
  func testSameRouteTypeWithDifferentUUIDsAreNotEqual() {
    let id1 = UUID()
    let id2 = UUID()

    #expect(AppRoute.listing(id1) != AppRoute.listing(id2))
    #expect(AppRoute.property(id1) != AppRoute.property(id2))
  }

  // MARK: - Non-UUID Route Equality Tests

  @Test("Tab destination routes are equal")
  func testTabDestinationRoutesAreEqual() {
    #expect(AppRoute.workspace == AppRoute.workspace)
    #expect(AppRoute.propertiesList == AppRoute.propertiesList)
    #expect(AppRoute.listingsList == AppRoute.listingsList)
    #expect(AppRoute.realtorsList == AppRoute.realtorsList)
    #expect(AppRoute.settingsRoot == AppRoute.settingsRoot)
  }

  @Test("Different tab destination routes are NOT equal")
  func testDifferentTabDestinationRoutesAreNotEqual() {
    #expect(AppRoute.workspace != AppRoute.propertiesList)
    #expect(AppRoute.propertiesList != AppRoute.listingsList)
    #expect(AppRoute.listingsList != AppRoute.realtorsList)
  }

  @Test("WorkItemRef routes with same content are equal")
  func testWorkItemRefRoutesAreEqual() {
    let taskId = UUID()
    let activityId = UUID()

    let taskRef1 = WorkItemRef.task(id: taskId)
    let taskRef2 = WorkItemRef.task(id: taskId)
    #expect(AppRoute.workItem(taskRef1) == AppRoute.workItem(taskRef2))

    let activityRef1 = WorkItemRef.activity(id: activityId)
    let activityRef2 = WorkItemRef.activity(id: activityId)
    #expect(AppRoute.workItem(activityRef1) == AppRoute.workItem(activityRef2))
  }

  @Test("WorkItemRef routes with different IDs are NOT equal")
  func testWorkItemRefRoutesWithDifferentIDsAreNotEqual() {
    let id1 = UUID()
    let id2 = UUID()

    let taskRef1 = WorkItemRef.task(id: id1)
    let taskRef2 = WorkItemRef.task(id: id2)
    #expect(AppRoute.workItem(taskRef1) != AppRoute.workItem(taskRef2))
  }

  @Test("SettingsSection routes are equal when same section")
  func testSettingsSectionRoutesAreEqual() {
    #expect(AppRoute.settings(.listingTypes) == AppRoute.settings(.listingTypes))
  }

  @Test("StagedListings routes are equal when same stage")
  func testStagedListingsRoutesAreEqual() {
    #expect(AppRoute.stagedListings(.pending) == AppRoute.stagedListings(.pending))
    #expect(AppRoute.stagedListings(.live) == AppRoute.stagedListings(.live))
  }

  @Test("StagedListings routes with different stages are NOT equal")
  func testStagedListingsRoutesWithDifferentStagesAreNotEqual() {
    #expect(AppRoute.stagedListings(.pending) != AppRoute.stagedListings(.live))
  }

}

// MARK: - AppRouterDeepLinkStateRestorationTests

struct AppRouterDeepLinkStateRestorationTests {

  @Test("Navigation preserves order of routes in path")
  func testNavigationPreservesOrderOfRoutes() {
    var router = AppRouter()
    let ids = (0 ..< 5).map { _ in UUID() }

    for id in ids {
      router.navigate(to: .listing(id))
    }

    let currentPath = router.paths[router.selectedDestination] ?? []
    #expect(currentPath.count == 5)

    for (index, id) in ids.enumerated() {
      #expect(currentPath[index] == .listing(id))
    }
  }

  @Test("Multiple navigations build correct path stack")
  func testMultipleNavigationsBuildCorrectStack() {
    var router = AppRouter()

    let listingId = UUID()
    let propertyId = UUID()
    let realtorId = UUID()

    router.navigate(to: .listing(listingId))
    router.navigate(to: .property(propertyId))
    router.navigate(to: .realtor(realtorId))

    let currentPath = router.paths[router.selectedDestination] ?? []
    #expect(currentPath == [
      .listing(listingId),
      .property(propertyId),
      .realtor(realtorId)
    ])
  }

  @Test("Switching destinations preserves paths of other destinations")
  func testSwitchingDestinationsPreservesOtherPaths() {
    var router = AppRouter()

    // Build up path on workspace
    router.selectedDestination = .tab(.workspace)
    router.navigate(to: .listing(UUID()))
    router.navigate(to: .property(UUID()))

    // Build up path on listings
    router.navigate(to: .realtor(UUID()), on: .tab(.listings))

    // Build up path on a stage
    router.navigate(to: .listing(UUID()), on: .stage(.pending))
    router.navigate(to: .property(UUID()), on: .stage(.pending))
    router.navigate(to: .realtor(UUID()), on: .stage(.pending))

    // Switch to listings (programmatic - preserves paths)
    router.setSelectedDestination(.tab(.listings))

    // Verify all paths are preserved
    let workspacePath = router.paths[.tab(.workspace)] ?? []
    let listingsPath = router.paths[.tab(.listings)] ?? []
    let pendingPath = router.paths[.stage(.pending)] ?? []

    #expect(workspacePath.count == 2)
    #expect(listingsPath.count == 1)
    #expect(pendingPath.count == 3)
  }

  @Test("State restoration scenario: deep link then user navigation")
  func testStateRestorationDeepLinkThenUserNav() {
    var router = AppRouter()

    // Simulate deep link: programmatically select destination and navigate
    router.setSelectedDestination(.tab(.listings))
    router.navigate(to: .listing(UUID()))

    // User then navigates further
    router.navigate(to: .property(UUID()))
    router.navigate(to: .realtor(UUID()))

    let listingsPath = router.paths[.tab(.listings)] ?? []
    #expect(listingsPath.count == 3)

    // User taps listings tab again (should pop to root)
    router.userSelectDestination(.tab(.listings))
    let listingsPathAfterTap = router.paths[.tab(.listings)] ?? []
    #expect(listingsPathAfterTap.isEmpty)
  }

  @Test("Default router state")
  func testDefaultRouterState() {
    let router = AppRouter()

    #expect(router.selectedDestination == .tab(.workspace))
    #expect(router.selectedTab == .workspace)
    #expect(router.phonePath.isEmpty)
    #expect(router.paths.isEmpty)
  }
}
