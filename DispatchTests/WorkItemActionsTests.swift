
import SwiftData
import SwiftUI
import Testing
@testable import DispatchApp

struct WorkItemActionsTests {

  @Test
  func testCurrentUserIdUpdates() async throws {
    // Setup
    let actions = await MainActor.run { WorkItemActions() }
    let initialID = await MainActor.run { actions.currentUserId }

    // Assert Initial State
    #expect(initialID == WorkItemActions.unauthenticatedUserId)

    // Simulating the update that happens in ContentView.onChange(of: currentUserId)
    let newUserID = UUID()
    await MainActor.run {
      actions.currentUserId = newUserID
    }

    // Assert Invariant: ID must match the pushed value
    let updatedID = await MainActor.run { actions.currentUserId }
    #expect(updatedID == newUserID)
  }
}
