//
//  DatePillTests.swift
//  DispatchTests
//
//  Tests for DatePill accessibility labels
//  Created by Claude on 2025-01-17.
//

// swiftlint:disable force_unwrapping

import Foundation
import Testing
@testable import DispatchApp

struct DatePillTests {

  // MARK: - Accessibility Label Tests

  @Test("DatePill shows 'Due date' prefix for future dates")
  func testFutureDateAccessibilityLabel() {
    let calendar = Calendar.current
    let futureDate = calendar.date(byAdding: .day, value: 7, to: Date())!
    let pill = DatePill(date: futureDate)

    #expect(pill.accessibilityLabelText.hasPrefix("Due date:"))
    #expect(!pill.isOverdue)
  }

  @Test("DatePill shows 'Due date' prefix for today")
  func testTodayAccessibilityLabel() {
    let today = Date()
    let pill = DatePill(date: today)

    #expect(pill.accessibilityLabelText.hasPrefix("Due date:"))
    #expect(!pill.isOverdue)
  }

  @Test("DatePill shows 'Overdue' prefix for past dates")
  func testOverdueAccessibilityLabel() {
    let calendar = Calendar.current
    let pastDate = calendar.date(byAdding: .day, value: -1, to: Date())!
    let pill = DatePill(date: pastDate)

    #expect(pill.accessibilityLabelText.hasPrefix("Overdue:"))
    #expect(pill.isOverdue)
  }

  @Test("DatePill accessibilityLabel includes formatted date")
  func testAccessibilityLabelContainsDate() {
    let calendar = Calendar.current
    let specificDate = calendar.date(byAdding: .day, value: 3, to: Date())!
    let pill = DatePill(date: specificDate)

    // The accessibility label should contain a long-format date
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .none
    let expectedDatePart = formatter.string(from: specificDate)

    #expect(pill.accessibilityLabelText.contains(expectedDatePart))
  }

  // MARK: - Overdue Detection Tests

  @Test("DatePill correctly detects overdue state")
  func testOverdueDetection() {
    let calendar = Calendar.current

    // Yesterday - overdue
    let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
    #expect(DatePill(date: yesterday).isOverdue == true)

    // Last week - overdue
    let lastWeek = calendar.date(byAdding: .day, value: -7, to: Date())!
    #expect(DatePill(date: lastWeek).isOverdue == true)

    // Today - not overdue
    let startOfToday = calendar.startOfDay(for: Date())
    #expect(DatePill(date: startOfToday).isOverdue == false)

    // Tomorrow - not overdue
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
    #expect(DatePill(date: tomorrow).isOverdue == false)
  }

  @Test("DatePill boundary: start of today is not overdue")
  func testTodayBoundary() {
    let calendar = Calendar.current
    let startOfToday = calendar.startOfDay(for: Date())
    let pill = DatePill(date: startOfToday)

    #expect(!pill.isOverdue)
    #expect(pill.accessibilityLabelText.hasPrefix("Due date:"))
  }

  @Test("DatePill boundary: one second before today is overdue")
  func testYesterdayBoundary() {
    let calendar = Calendar.current
    let startOfToday = calendar.startOfDay(for: Date())
    let oneSecondBeforeToday = startOfToday.addingTimeInterval(-1)
    let pill = DatePill(date: oneSecondBeforeToday)

    #expect(pill.isOverdue)
    #expect(pill.accessibilityLabelText.hasPrefix("Overdue:"))
  }
}
