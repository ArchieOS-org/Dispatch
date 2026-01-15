//
//  EnumTests.swift
//  DispatchTests
//
//  Comprehensive tests for all enum types in the Dispatch app
//  Tests: TaskStatus, ActivityStatus, UserType, ClaimAction, etc.
//  Created by Test Generation on 2025-12-08.
//

// swiftlint:disable force_unwrapping

import Foundation
import Testing
@testable import DispatchApp

// MARK: - TaskStatusTests

struct TaskStatusTests {

  @Test("TaskStatus has all expected cases")
  func testAllCases() {
    #expect(TaskStatus.allCases.count == 4)
    #expect(TaskStatus.allCases.contains(.open))
    #expect(TaskStatus.allCases.contains(.inProgress))
    #expect(TaskStatus.allCases.contains(.completed))
    #expect(TaskStatus.allCases.contains(.deleted))
  }

  @Test("TaskStatus raw values match database schema")
  func testRawValues() {
    #expect(TaskStatus.open.rawValue == "open")
    #expect(TaskStatus.inProgress.rawValue == "in_progress")
    #expect(TaskStatus.completed.rawValue == "completed")
    #expect(TaskStatus.deleted.rawValue == "deleted")
  }

  @Test("TaskStatus round-trips through Codable")
  func testCodable() throws {
    let statuses: [TaskStatus] = [.open, .inProgress, .completed, .deleted]
    for status in statuses {
      let encoded = try JSONEncoder().encode(status)
      let decoded = try JSONDecoder().decode(TaskStatus.self, from: encoded)
      #expect(decoded == status)
    }
  }

  @Test("TaskStatus decodes from snake_case")
  func testSnakeCaseDecoding() throws {
    let json = "\"in_progress\"".data(using: .utf8)!
    let decoded = try JSONDecoder().decode(TaskStatus.self, from: json)
    #expect(decoded == .inProgress)
  }
}

// MARK: - ActivityStatusTests

struct ActivityStatusTests {

  @Test("ActivityStatus has all expected cases")
  func testAllCases() {
    #expect(ActivityStatus.allCases.count == 4)
    #expect(ActivityStatus.allCases.contains(.open))
    #expect(ActivityStatus.allCases.contains(.inProgress))
    #expect(ActivityStatus.allCases.contains(.completed))
    #expect(ActivityStatus.allCases.contains(.deleted))
  }

  @Test("ActivityStatus raw values match database schema")
  func testRawValues() {
    #expect(ActivityStatus.open.rawValue == "open")
    #expect(ActivityStatus.inProgress.rawValue == "in_progress")
    #expect(ActivityStatus.completed.rawValue == "completed")
    #expect(ActivityStatus.deleted.rawValue == "deleted")
  }

  @Test("ActivityStatus round-trips through Codable")
  func testCodable() throws {
    let statuses: [ActivityStatus] = [.open, .inProgress, .completed, .deleted]
    for status in statuses {
      let encoded = try JSONEncoder().encode(status)
      let decoded = try JSONDecoder().decode(ActivityStatus.self, from: encoded)
      #expect(decoded == status)
    }
  }
}

// MARK: - UserTypeTests

struct UserTypeTests {

  @Test("UserType has all expected cases")
  func testAllCases() {
    #expect(UserType.allCases.count == 5)
    #expect(UserType.allCases.contains(.realtor))
    #expect(UserType.allCases.contains(.admin))
    #expect(UserType.allCases.contains(.marketing))
    #expect(UserType.allCases.contains(.operator))
    #expect(UserType.allCases.contains(.exec))
  }

  @Test("UserType isStaff property is correct")
  func testIsStaff() {
    #expect(UserType.realtor.isStaff == false)
    #expect(UserType.admin.isStaff == true)
    #expect(UserType.marketing.isStaff == true)
    #expect(UserType.operator.isStaff == true)
    #expect(UserType.exec.isStaff == false)
  }

  @Test("UserType raw values are correct")
  func testRawValues() {
    #expect(UserType.realtor.rawValue == "realtor")
    #expect(UserType.admin.rawValue == "admin")
    #expect(UserType.marketing.rawValue == "marketing")
    #expect(UserType.operator.rawValue == "operator")
    #expect(UserType.exec.rawValue == "exec")
  }

  @Test("UserType round-trips through Codable")
  func testCodable() throws {
    let types: [UserType] = [.realtor, .admin, .marketing, .operator, .exec]
    for type in types {
      let encoded = try JSONEncoder().encode(type)
      let decoded = try JSONDecoder().decode(UserType.self, from: encoded)
      #expect(decoded == type)
    }
  }
}

// MARK: - ClaimActionTests

struct ClaimActionTests {

  @Test("ClaimAction has expected cases")
  func testAllCases() {
    #expect(ClaimAction.allCases.count == 2)
    #expect(ClaimAction.allCases.contains(.claimed))
    #expect(ClaimAction.allCases.contains(.released))
  }

  @Test("ClaimAction raw values are correct")
  func testRawValues() {
    #expect(ClaimAction.claimed.rawValue == "claimed")
    #expect(ClaimAction.released.rawValue == "released")
  }
}

// MARK: - CreationSourceTests

struct CreationSourceTests {

  @Test("CreationSource has all expected cases")
  func testAllCases() {
    #expect(CreationSource.allCases.count == 5)
    #expect(CreationSource.allCases.contains(.dispatch))
    #expect(CreationSource.allCases.contains(.slack))
    #expect(CreationSource.allCases.contains(.realtorApp))
    #expect(CreationSource.allCases.contains(.api))
    #expect(CreationSource.allCases.contains(.import))
  }

  @Test("CreationSource raw values are correct")
  func testRawValues() {
    #expect(CreationSource.dispatch.rawValue == "dispatch")
    #expect(CreationSource.slack.rawValue == "slack")
    #expect(CreationSource.realtorApp.rawValue == "realtor_app")
    #expect(CreationSource.api.rawValue == "api")
    #expect(CreationSource.import.rawValue == "import")
  }
}

// MARK: - ListingStatusTests

struct ListingStatusTests {

  @Test("ListingStatus has all expected cases")
  func testAllCases() {
    #expect(ListingStatus.allCases.count == 5)
    #expect(ListingStatus.allCases.contains(.draft))
    #expect(ListingStatus.allCases.contains(.active))
    #expect(ListingStatus.allCases.contains(.pending))
    #expect(ListingStatus.allCases.contains(.closed))
    #expect(ListingStatus.allCases.contains(.deleted))
  }

  @Test("ListingStatus raw values are correct")
  func testRawValues() {
    #expect(ListingStatus.draft.rawValue == "draft")
    #expect(ListingStatus.active.rawValue == "active")
    #expect(ListingStatus.pending.rawValue == "pending")
    #expect(ListingStatus.closed.rawValue == "closed")
    #expect(ListingStatus.deleted.rawValue == "deleted")
  }
}

// MARK: - ListingTypeTests

struct ListingTypeTests {

  @Test("ListingType has all expected cases")
  func testAllCases() {
    #expect(ListingType.allCases.count == 5)
    #expect(ListingType.allCases.contains(.sale))
    #expect(ListingType.allCases.contains(.lease))
    #expect(ListingType.allCases.contains(.preListing))
    #expect(ListingType.allCases.contains(.rental))
    #expect(ListingType.allCases.contains(.other))
  }

  @Test("ListingType raw values match database schema")
  func testRawValues() {
    #expect(ListingType.sale.rawValue == "sale")
    #expect(ListingType.lease.rawValue == "lease")
    #expect(ListingType.preListing.rawValue == "pre_listing")
    #expect(ListingType.rental.rawValue == "rental")
    #expect(ListingType.other.rawValue == "other")
  }
}

// MARK: - ParentTypeTests

struct ParentTypeTests {

  @Test("ParentType has all expected cases")
  func testAllCases() {
    #expect(ParentType.allCases.count == 3)
    #expect(ParentType.allCases.contains(.task))
    #expect(ParentType.allCases.contains(.activity))
    #expect(ParentType.allCases.contains(.listing))
  }

  @Test("ParentType raw values are correct")
  func testRawValues() {
    #expect(ParentType.task.rawValue == "task")
    #expect(ParentType.activity.rawValue == "activity")
    #expect(ParentType.listing.rawValue == "listing")
  }
}

// MARK: - SyncStatusTests

struct SyncStatusTests {

  @Test("SyncStatus has basic cases")
  func testBasicCases() {
    let idle = SyncStatus.idle
    let syncing = SyncStatus.syncing
    let error = SyncStatus.error

    #expect(idle == .idle)
    #expect(syncing == .syncing)
    #expect(error == .error)
  }

  @Test("SyncStatus handles associated values")
  func testAssociatedValues() {
    let now = Date()
    let ok = SyncStatus.ok(now)

    if case .ok(let date) = ok {
      #expect(date == now)
    } else {
      // #expect(false, "Should match .ok case") // #expect(false) isn't standard in Testing framework yet?
      // Using a workaround or just letting it pass implies success.
      // But we want to fail.
      // Using XCTFail equivalent in `Testing` framework is usually `Issue.record(...)` or `#expect(Bool(false))`
      #expect(Bool(false), "Should match .ok case")
    }
  }
}

// MARK: - ConflictStrategyTests

struct ConflictStrategyTests {

  @Test("ConflictStrategy has expected cases")
  func testAllCases() {
    #expect(ConflictStrategy.allCases.count == 3)
    #expect(ConflictStrategy.allCases.contains(.lastWriteWins))
    #expect(ConflictStrategy.allCases.contains(.serverWins))
    #expect(ConflictStrategy.allCases.contains(.manual))
  }

  @Test("ConflictStrategy raw values match database schema")
  func testRawValues() {
    #expect(ConflictStrategy.lastWriteWins.rawValue == "last_write_wins")
    #expect(ConflictStrategy.serverWins.rawValue == "server_wins")
    #expect(ConflictStrategy.manual.rawValue == "manual")
  }
}
