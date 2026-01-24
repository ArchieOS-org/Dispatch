//
//  SearchIndexServiceTests.swift
//  DispatchTests
//
//  Unit tests for SearchIndexService: tokenization, ranking, and incremental updates.
//

import Foundation
import Testing
@testable import DispatchApp

// MARK: - Test Helpers

/// Extension to convert TaskItem to SearchableTask for test data.
/// Tests use TaskItem for convenience but InitialSearchData expects SearchableTask DTOs.
extension TaskItem {
  var asSearchable: SearchableTask {
    SearchableTask(
      id: id,
      title: title,
      taskDescription: taskDescription,
      statusRawValue: status.rawValue,
      statusDisplayName: status.displayName,
      updatedAt: updatedAt
    )
  }
}

/// Extension to convert Listing to SearchableListing for test data.
extension Listing {
  var asSearchable: SearchableListing {
    SearchableListing(
      id: id,
      address: address,
      city: city,
      postalCode: postalCode,
      statusRawValue: status.rawValue,
      statusDisplayName: status.displayName,
      updatedAt: updatedAt
    )
  }
}

// MARK: - SearchIndexServiceTests

@Suite("SearchIndexService Tests")
struct SearchIndexServiceTests {

  // MARK: - Tokenization Tests

  @Test("tokenize splits on non-alphanumerics and drops short tokens")
  func testTokenizeSplitsAndFilters() {
    let result = SearchDoc.tokenize("Hello, World! How are you?")
    #expect(result == ["hello", "world", "how", "are", "you"])
  }

  @Test("tokenize preserves numeric tokens of any length")
  func testTokenizePreservesNumbers() {
    let result = SearchDoc.tokenize("Unit 1 at 123 Main St")
    #expect(result.contains("1"))
    #expect(result.contains("123"))
    #expect(result.contains("unit"))
    #expect(result.contains("main"))
  }

  @Test("tokenize deduplicates tokens while preserving order")
  func testTokenizeDeduplicates() {
    let result = SearchDoc.tokenize("test test TEST testing")
    #expect(result == ["test", "testing"])
  }

  @Test("tokenize removes diacritics")
  func testTokenizeRemovesDiacritics() {
    let result = SearchDoc.tokenize("Café résumé naïve")
    #expect(result.contains("cafe"))
    #expect(result.contains("resume"))
    #expect(result.contains("naive"))
  }

  // MARK: - Normalization Tests

  @Test("normalize lowercases and collapses whitespace")
  func testNormalizeBasic() {
    let result = SearchDoc.normalize("  Hello   World  ")
    #expect(result == "hello world")
  }

  @Test("normalize removes diacritics")
  func testNormalizeDiacritics() {
    let result = SearchDoc.normalize("Café")
    #expect(result == "cafe")
  }

  // MARK: - SearchDoc Factory Tests

  @Test("SearchDoc.from(task:) creates correct document")
  func testSearchDocFromTask() {
    let task = TaskItem(
      title: "Fix Window",
      taskDescription: "Replace broken pane",
      declaredBy: UUID()
    )

    let doc = SearchDoc.from(task: task.asSearchable)

    #expect(doc.id == task.id)
    #expect(doc.type == .task)
    #expect(doc.primaryText == "Fix Window")
    #expect(doc.secondaryText == "Replace broken pane")
    #expect(doc.searchKey.contains("fix"))
    #expect(doc.searchKey.contains("window"))
  }

  @Test("SearchDoc.from(listing:) creates correct document")
  func testSearchDocFromListing() {
    let listing = Listing(
      address: "123 Main Street",
      city: "Toronto",
      province: "ON",
      postalCode: "M5V 1A1",
      country: "Canada",
      ownedBy: UUID()
    )

    let doc = SearchDoc.from(listing: listing.asSearchable)

    #expect(doc.id == listing.id)
    #expect(doc.type == .listing)
    #expect(doc.primaryText == "123 Main Street")
    #expect(doc.secondaryText.contains("Toronto"))
  }

  // MARK: - Search Service Tests

  @Test("search returns empty results for empty index")
  func testEmptyIndex() async {
    let service = SearchIndexService()
    let results = await service.search("test", limit: 10)
    #expect(results.isEmpty)
  }

  @Test("warmStart indexes all entities")
  func testWarmStart() async {
    let service = SearchIndexService()

    let task = TaskItem(title: "Test Task", declaredBy: UUID())
    let data = InitialSearchData(
      realtors: [],
      listings: [],
      properties: [],
      tasks: [task.asSearchable]
    )

    await service.warmStart(with: data)

    let isReady = await service.isReady
    #expect(isReady)

    let results = await service.search("test", limit: 10)
    #expect(results.count == 1)
    #expect(results.first?.id == task.id)
  }

  @Test("search matches on phrase")
  func testPhraseMatch() async {
    let service = SearchIndexService()

    let task1 = TaskItem(title: "Fix Broken Window", declaredBy: UUID())
    let task2 = TaskItem(title: "Window Repair", declaredBy: UUID())
    let data = InitialSearchData(
      realtors: [],
      listings: [],
      properties: [],
      tasks: [task1.asSearchable, task2.asSearchable]
    )

    await service.warmStart(with: data)
    let results = await service.search("fix broken window", limit: 10)

    // Phrase match should rank first
    #expect(results.first?.id == task1.id)
  }

  @Test("search ranks type priority correctly")
  func testTypePriorityRanking() async {
    let service = SearchIndexService()

    let task = TaskItem(title: "Test Item", declaredBy: UUID())
    let listing = Listing(
      address: "Test Item Street",
      city: "City",
      province: "ON",
      postalCode: "M5V",
      country: "Canada",
      ownedBy: UUID()
    )

    let data = InitialSearchData(
      realtors: [],
      listings: [listing.asSearchable],
      properties: [],
      tasks: [task.asSearchable]
    )

    await service.warmStart(with: data)
    let results = await service.search("test item", limit: 10)

    // Listing should rank higher than task (lower rawValue = higher priority)
    #expect(results.count == 2)
    #expect(results.first?.type == .listing)
    #expect(results.last?.type == .task)
  }

  // MARK: - Incremental Update Tests

  @Test("apply insert adds document to index")
  func testApplyInsert() async {
    let service = SearchIndexService()

    // Start with empty data - use typed empty arrays
    let emptyRealtors: [SearchableRealtor] = []
    let emptyListings: [SearchableListing] = []
    let emptyProperties: [SearchableProperty] = []
    let emptyTasks: [SearchableTask] = []
    let data = InitialSearchData(
      realtors: emptyRealtors,
      listings: emptyListings,
      properties: emptyProperties,
      tasks: emptyTasks
    )
    await service.warmStart(with: data)

    // Insert a new task
    let task = TaskItem(title: "New Task", declaredBy: UUID())
    let doc = SearchDoc.from(task: task.asSearchable)
    await service.apply(change: .insert(doc))

    let results = await service.search("new task", limit: 10)
    #expect(results.count == 1)
    #expect(results.first?.id == task.id)
  }

  @Test("apply update replaces document in index")
  func testApplyUpdate() async {
    let service = SearchIndexService()

    let task = TaskItem(title: "Original Title", declaredBy: UUID())
    let data = InitialSearchData(realtors: [], listings: [], properties: [], tasks: [task.asSearchable])
    await service.warmStart(with: data)

    // Update the task title
    task.title = "Updated Title"
    let updatedDoc = SearchDoc.from(task: task.asSearchable)
    await service.apply(change: .update(updatedDoc))

    // Old title should not match
    let oldResults = await service.search("original", limit: 10)
    #expect(oldResults.isEmpty)

    // New title should match
    let newResults = await service.search("updated", limit: 10)
    #expect(newResults.count == 1)
    #expect(newResults.first?.id == task.id)
  }

  @Test("apply delete removes document from index")
  func testApplyDelete() async {
    let service = SearchIndexService()

    let task = TaskItem(title: "To Delete", declaredBy: UUID())
    let data = InitialSearchData(realtors: [], listings: [], properties: [], tasks: [task.asSearchable])
    await service.warmStart(with: data)

    // Verify it exists
    var results = await service.search("delete", limit: 10)
    #expect(results.count == 1)

    // Delete it
    await service.apply(change: .delete(id: task.id))

    // Should no longer exist
    results = await service.search("delete", limit: 10)
    #expect(results.isEmpty)
  }

  // MARK: - Empty Query Tests

  @Test("empty query returns recent docs with type priority")
  func testEmptyQueryReturnsRecent() async {
    let service = SearchIndexService()

    let task = TaskItem(title: "Task", declaredBy: UUID())
    let listing = Listing(
      address: "Listing",
      city: "City",
      province: "ON",
      postalCode: "M5V",
      country: "Canada",
      ownedBy: UUID()
    )

    let data = InitialSearchData(
      realtors: [],
      listings: [listing.asSearchable],
      properties: [],
      tasks: [task.asSearchable]
    )

    await service.warmStart(with: data)
    let results = await service.search("", limit: 10)

    // Should return both, listing first (higher priority)
    #expect(results.count == 2)
    #expect(results.first?.type == .listing)
  }

  // MARK: - Ranking Order Tests

  @Test("ranking order: phrase match beats token match")
  func testRankingPhraseBeatsToken() async {
    let service = SearchIndexService()

    // task1 has phrase match for "fix window"
    let task1 = TaskItem(title: "Fix Window", declaredBy: UUID())
    // task2 has both tokens but not as phrase
    let task2 = TaskItem(title: "Window needs a fix", declaredBy: UUID())

    let data = InitialSearchData(
      realtors: [],
      listings: [],
      properties: [],
      tasks: [task1.asSearchable, task2.asSearchable]
    )
    await service.warmStart(with: data)

    let results = await service.search("fix window", limit: 10)

    #expect(results.count == 2)
    #expect(results.first?.id == task1.id, "Phrase match should rank first")
  }

  @Test("ranking order: starts-with boost applies")
  func testRankingStartsWithBoost() async {
    let service = SearchIndexService()

    // Both have "window" but task1 starts with it
    let task1 = TaskItem(title: "Window Repair", declaredBy: UUID())
    let task2 = TaskItem(title: "Repair Window", declaredBy: UUID())

    let data = InitialSearchData(
      realtors: [],
      listings: [],
      properties: [],
      tasks: [task1.asSearchable, task2.asSearchable]
    )
    await service.warmStart(with: data)

    let results = await service.search("window", limit: 10)

    #expect(results.count == 2)
    #expect(results.first?.id == task1.id, "Starts-with should rank first")
  }

}
