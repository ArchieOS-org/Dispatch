//
//  UtilityTests.swift
//  DispatchTests
//
//  Tests for utility classes: ClaimFilter, DateSection
//  Created by Test Generation on 2025-12-08.
//

import Testing
import Foundation
@testable import DispatchApp

struct ClaimFilterTests {
    
    let currentUserId = UUID()
    let otherUserId = UUID()
    
    @Test("ClaimFilter has all expected cases")
    func testAllCases() {
        #expect(ClaimFilter.allCases.count == 3)
        #expect(ClaimFilter.allCases.contains(.mine))
        #expect(ClaimFilter.allCases.contains(.others))
        #expect(ClaimFilter.allCases.contains(.unclaimed))
    }
    
    @Test("ClaimFilter.mine matches correctly")
    func testMineFilter() {
        let filter = ClaimFilter.mine
        
        // Should match when claimedBy == currentUserId
        #expect(filter.matches(claimedBy: currentUserId, currentUserId: currentUserId) == true)
        
        // Should not match when claimedBy is different
        #expect(filter.matches(claimedBy: otherUserId, currentUserId: currentUserId) == false)
        
        // Should not match when unclaimed
        #expect(filter.matches(claimedBy: nil, currentUserId: currentUserId) == false)
    }
    
    @Test("ClaimFilter.others matches correctly")
    func testOthersFilter() {
        let filter = ClaimFilter.others
        
        // Should match when claimedBy is someone else
        #expect(filter.matches(claimedBy: otherUserId, currentUserId: currentUserId) == true)
        
        // Should not match when claimedBy is current user
        #expect(filter.matches(claimedBy: currentUserId, currentUserId: currentUserId) == false)
        
        // Should not match when unclaimed
        #expect(filter.matches(claimedBy: nil, currentUserId: currentUserId) == false)
    }
    
    @Test("ClaimFilter.unclaimed matches correctly")
    func testUnclaimedFilter() {
        let filter = ClaimFilter.unclaimed
        
        // Should match when claimedBy is nil
        #expect(filter.matches(claimedBy: nil, currentUserId: currentUserId) == true)
        
        // Should not match when claimedBy is set
        #expect(filter.matches(claimedBy: currentUserId, currentUserId: currentUserId) == false)
        #expect(filter.matches(claimedBy: otherUserId, currentUserId: currentUserId) == false)
    }
    
    @Test("ClaimFilter displayName returns correct value for tasks")
    func testDisplayNameTasks() {
        #expect(ClaimFilter.mine.displayName(forActivities: false) == "My Tasks")
        #expect(ClaimFilter.others.displayName(forActivities: false) == "Others'")
        #expect(ClaimFilter.unclaimed.displayName(forActivities: false) == "Unclaimed")
    }
    
    @Test("ClaimFilter displayName returns correct value for activities")
    func testDisplayNameActivities() {
        #expect(ClaimFilter.mine.displayName(forActivities: true) == "My Activities")
        #expect(ClaimFilter.others.displayName(forActivities: true) == "Others'")
        #expect(ClaimFilter.unclaimed.displayName(forActivities: true) == "Unclaimed")
    }
    
    @Test("ClaimFilter raw values are correct")
    func testRawValues() {
        #expect(ClaimFilter.mine.rawValue == "My Tasks")
        #expect(ClaimFilter.others.rawValue == "Others'")
        #expect(ClaimFilter.unclaimed.rawValue == "Unclaimed")
    }
    
    @Test("ClaimFilter is Identifiable with string id")
    func testIdentifiable() {
        #expect(ClaimFilter.mine.id == "My Tasks")
        #expect(ClaimFilter.others.id == "Others'")
        #expect(ClaimFilter.unclaimed.id == "Unclaimed")
    }
}

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