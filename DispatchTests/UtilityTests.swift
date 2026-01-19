//
//  UtilityTests.swift
//  DispatchTests
//
//  Tests for utility classes: ClaimFilter, DateSection
//  Created by Test Generation on 2025-12-08.
//

// swiftlint:disable force_unwrapping

import Foundation
import Testing
@testable import DispatchApp

// MARK: - ClaimFilterTests

struct ClaimFilterTests {

  let currentUserId = UUID()
  let otherUserId = UUID()

  @Test("AssignmentFilter has all expected cases")
  func testAllCases() {
    #expect(AssignmentFilter.allCases.count == 3)
    #expect(AssignmentFilter.allCases.contains(.mine))
    #expect(AssignmentFilter.allCases.contains(.others))
    #expect(AssignmentFilter.allCases.contains(.unassigned))
  }

  @Test("AssignmentFilter.mine matches correctly")
  func testMineFilter() {
    let filter = AssignmentFilter.mine

    // Should match when assigneeUserIds contains currentUserId
    #expect(filter.matches(assigneeUserIds: [currentUserId], currentUserId: currentUserId) == true)

    // Should not match when assigneeUserIds contains only other users
    #expect(filter.matches(assigneeUserIds: [otherUserId], currentUserId: currentUserId) == false)

    // Should not match when unassigned
    #expect(filter.matches(assigneeUserIds: [], currentUserId: currentUserId) == false)
  }

  @Test("AssignmentFilter.others matches correctly")
  func testOthersFilter() {
    let filter = AssignmentFilter.others

    // Should match when assigneeUserIds contains someone else (not current user)
    #expect(filter.matches(assigneeUserIds: [otherUserId], currentUserId: currentUserId) == true)

    // Should not match when assigneeUserIds contains current user
    #expect(filter.matches(assigneeUserIds: [currentUserId], currentUserId: currentUserId) == false)

    // Should not match when unassigned
    #expect(filter.matches(assigneeUserIds: [], currentUserId: currentUserId) == false)
  }

  @Test("AssignmentFilter.unassigned matches correctly")
  func testUnassignedFilter() {
    let filter = AssignmentFilter.unassigned

    // Should match when assigneeUserIds is empty
    #expect(filter.matches(assigneeUserIds: [], currentUserId: currentUserId) == true)

    // Should not match when assigneeUserIds is not empty
    #expect(filter.matches(assigneeUserIds: [currentUserId], currentUserId: currentUserId) == false)
    #expect(filter.matches(assigneeUserIds: [otherUserId], currentUserId: currentUserId) == false)
  }

  @Test("AssignmentFilter displayName returns correct value for tasks")
  func testDisplayNameTasks() {
    #expect(AssignmentFilter.mine.displayName(forActivities: false) == "My Tasks")
    #expect(AssignmentFilter.others.displayName(forActivities: false) == "Others'")
    #expect(AssignmentFilter.unassigned.displayName(forActivities: false) == "Available")
  }

  @Test("AssignmentFilter displayName returns correct value for activities")
  func testDisplayNameActivities() {
    #expect(AssignmentFilter.mine.displayName(forActivities: true) == "My Activities")
    #expect(AssignmentFilter.others.displayName(forActivities: true) == "Others'")
    #expect(AssignmentFilter.unassigned.displayName(forActivities: true) == "Available")
  }

  @Test("AssignmentFilter raw values are correct")
  func testRawValues() {
    #expect(AssignmentFilter.mine.rawValue == "Assigned to Me")
    #expect(AssignmentFilter.others.rawValue == "Others'")
    #expect(AssignmentFilter.unassigned.rawValue == "Unassigned")
  }

  @Test("AssignmentFilter is Identifiable with string id")
  func testIdentifiable() {
    #expect(AssignmentFilter.mine.id == "Assigned to Me")
    #expect(AssignmentFilter.others.id == "Others'")
    #expect(AssignmentFilter.unassigned.id == "Unassigned")
  }
}

// MARK: - DateSectionTests

struct DateSectionTests {

  @Test("DateSection has all expected cases")
  func testAllCases() {
    #expect(DateSection.allCases.count == 5)
    #expect(DateSection.allCases.contains(.overdue))
    #expect(DateSection.allCases.contains(.today))
    #expect(DateSection.allCases.contains(.tomorrow))
    #expect(DateSection.allCases.contains(.upcoming))
    #expect(DateSection.allCases.contains(.noDueDate))
  }

  @Test("DateSection.section returns noDueDate for nil")
  func testNilDate() {
    #expect(DateSection.section(for: nil) == .noDueDate)
  }

  @Test("DateSection.section returns overdue for past dates")
  func testOverdue() {
    let calendar = Calendar.current
    let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
    let lastWeek = calendar.date(byAdding: .day, value: -7, to: Date())!

    #expect(DateSection.section(for: yesterday) == .overdue)
    #expect(DateSection.section(for: lastWeek) == .overdue)
  }

  @Test("DateSection.section returns today for today's dates")
  func testToday() {
    let now = Date()
    let calendar = Calendar.current
    let startOfToday = calendar.startOfDay(for: now)
    let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!.addingTimeInterval(-1)

    #expect(DateSection.section(for: startOfToday) == .today)
    #expect(DateSection.section(for: now) == .today)
    #expect(DateSection.section(for: endOfToday) == .today)
  }

  @Test("DateSection.section returns tomorrow for tomorrow's dates")
  func testTomorrow() {
    let calendar = Calendar.current
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
    let startOfTomorrow = calendar.startOfDay(for: tomorrow)

    #expect(DateSection.section(for: startOfTomorrow) == .tomorrow)
  }

  @Test("DateSection.section returns upcoming for future dates")
  func testUpcoming() {
    let calendar = Calendar.current
    let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: Date())!
    let nextWeek = calendar.date(byAdding: .day, value: 7, to: Date())!
    let nextMonth = calendar.date(byAdding: .month, value: 1, to: Date())!

    #expect(DateSection.section(for: dayAfterTomorrow) == .upcoming)
    #expect(DateSection.section(for: nextWeek) == .upcoming)
    #expect(DateSection.section(for: nextMonth) == .upcoming)
  }

  @Test("DateSection raw values are correct")
  func testRawValues() {
    #expect(DateSection.overdue.rawValue == "Overdue")
    #expect(DateSection.today.rawValue == "Today")
    #expect(DateSection.tomorrow.rawValue == "Tomorrow")
    #expect(DateSection.upcoming.rawValue == "Upcoming")
    #expect(DateSection.noDueDate.rawValue == "No Due Date")
  }

  @Test("DateSection is Identifiable with string id")
  func testIdentifiable() {
    #expect(DateSection.overdue.id == "Overdue")
    #expect(DateSection.today.id == "Today")
    #expect(DateSection.tomorrow.id == "Tomorrow")
  }

  @Test("DateSection boundary conditions work correctly")
  func testBoundaryConditions() {
    let calendar = Calendar.current
    let now = Date()
    let startOfToday = calendar.startOfDay(for: now)

    // One second before midnight today
    let almostMidnight = calendar.date(byAdding: .day, value: 1, to: startOfToday)!.addingTimeInterval(-1)
    #expect(DateSection.section(for: almostMidnight) == .today)

    // Exactly midnight (start of tomorrow)
    let midnight = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
    #expect(DateSection.section(for: midnight) == .tomorrow)

    // One second before midnight tomorrow
    let almostMidnightTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfToday)!.addingTimeInterval(-1)
    #expect(DateSection.section(for: almostMidnightTomorrow) == .tomorrow)

    // Exactly midnight day after tomorrow
    let midnightDayAfter = calendar.date(byAdding: .day, value: 2, to: startOfToday)!
    #expect(DateSection.section(for: midnightDayAfter) == .upcoming)
  }
}
