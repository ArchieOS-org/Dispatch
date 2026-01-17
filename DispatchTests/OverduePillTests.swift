//
//  OverduePillTests.swift
//  DispatchTests
//
//  Tests for OverduePill accessibility label formatting.
//

import Testing
@testable import DispatchApp

struct OverduePillTests {

  @Test("accessibilityLabel returns singular for count=1")
  func testAccessibilityLabelSingular() {
    let pill = OverduePill(count: 1)
    #expect(pill.accessibilityLabel == "1 overdue task")
  }

  @Test("accessibilityLabel returns plural for count=0")
  func testAccessibilityLabelZero() {
    let pill = OverduePill(count: 0)
    #expect(pill.accessibilityLabel == "0 overdue tasks")
  }

  @Test("accessibilityLabel returns plural for count=5")
  func testAccessibilityLabelPlural() {
    let pill = OverduePill(count: 5)
    #expect(pill.accessibilityLabel == "5 overdue tasks")
  }

  @Test("accessibilityLabel returns plural for large counts")
  func testAccessibilityLabelLargeCount() {
    let pill = OverduePill(count: 100)
    #expect(pill.accessibilityLabel == "100 overdue tasks")
  }
}
