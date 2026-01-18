//
//  DeepLinkHandlerTests.swift
//  DispatchTests
//
//  Created for Deep Linking Support
//

import Foundation
import Testing
@testable import DispatchApp

// MARK: - DeepLinkHandlerTests

struct DeepLinkHandlerTests {

  // MARK: - URL Detection Tests

  @Test
  func isDeepLink_withDispatchScheme_returnsTrue() throws {
    let url = try #require(URL(string: "dispatch://listing/123"))
    #expect(DeepLinkHandler.isDeepLink(url) == true)
  }

  @Test
  func isDeepLink_withOAuthScheme_returnsFalse() throws {
    let url = try #require(URL(string: "com.googleusercontent.apps.123://callback"))
    #expect(DeepLinkHandler.isDeepLink(url) == false)
  }

  @Test
  func isDeepLink_withHTTPSScheme_returnsFalse() throws {
    let url = try #require(URL(string: "https://example.com"))
    #expect(DeepLinkHandler.isDeepLink(url) == false)
  }

  @Test
  func isOAuthCallback_withGoogleScheme_returnsTrue() throws {
    let url = try #require(
      URL(string: "com.googleusercontent.apps.428022180682-9fm6p0e0l3o8j1bnmf78b5uon8lkhntt://oauth")
    )
    #expect(DeepLinkHandler.isOAuthCallback(url) == true)
  }

  @Test
  func isOAuthCallback_withDispatchScheme_returnsFalse() throws {
    let url = try #require(URL(string: "dispatch://listing/123"))
    #expect(DeepLinkHandler.isOAuthCallback(url) == false)
  }

  // MARK: - Listing URL Parsing Tests

  @Test
  func parse_validListingURL_returnsListingResult() throws {
    let uuid = UUID()
    let url = try #require(URL(string: "dispatch://listing/\(uuid.uuidString)"))

    let result = DeepLinkHandler.parse(url)

    #expect(result == .listing(uuid))
  }

  @Test
  func parse_validListingURL_lowercaseUUID_returnsListingResult() throws {
    let uuid = UUID()
    let url = try #require(URL(string: "dispatch://listing/\(uuid.uuidString.lowercased())"))

    let result = DeepLinkHandler.parse(url)

    #expect(result == .listing(uuid))
  }

  // MARK: - Task URL Parsing Tests

  @Test
  func parse_validTaskURL_returnsTaskResult() throws {
    let uuid = UUID()
    let url = try #require(URL(string: "dispatch://task/\(uuid.uuidString)"))

    let result = DeepLinkHandler.parse(url)

    #expect(result == .task(uuid))
  }

  // MARK: - Property URL Parsing Tests

  @Test
  func parse_validPropertyURL_returnsPropertyResult() throws {
    let uuid = UUID()
    let url = try #require(URL(string: "dispatch://property/\(uuid.uuidString)"))

    let result = DeepLinkHandler.parse(url)

    #expect(result == .property(uuid))
  }

  // MARK: - Invalid URL Parsing Tests

  @Test
  func parse_wrongScheme_returnsInvalid() throws {
    let url = try #require(URL(string: "https://listing/\(UUID().uuidString)"))

    let result = DeepLinkHandler.parse(url)

    if case .invalid(let reason) = result {
      #expect(reason.contains("https"))
    } else {
      Issue.record("Expected invalid result")
    }
  }

  @Test
  func parse_missingHost_returnsInvalid() throws {
    // URL without host component
    let url = try #require(URL(string: "dispatch:///\(UUID().uuidString)"))

    let result = DeepLinkHandler.parse(url)

    if case .invalid = result {
      // Expected
    } else {
      Issue.record("Expected invalid result for missing host")
    }
  }

  @Test
  func parse_invalidUUID_returnsInvalid() throws {
    let url = try #require(URL(string: "dispatch://listing/not-a-valid-uuid"))

    let result = DeepLinkHandler.parse(url)

    if case .invalid(let reason) = result {
      #expect(reason.contains("Invalid UUID"))
    } else {
      Issue.record("Expected invalid result for bad UUID")
    }
  }

  @Test
  func parse_unknownEntityType_returnsInvalid() throws {
    let url = try #require(URL(string: "dispatch://unknown/\(UUID().uuidString)"))

    let result = DeepLinkHandler.parse(url)

    if case .invalid(let reason) = result {
      #expect(reason.contains("Unknown entity type"))
    } else {
      Issue.record("Expected invalid result for unknown entity")
    }
  }

  @Test
  func parse_missingUUID_returnsInvalid() throws {
    let url = try #require(URL(string: "dispatch://listing"))

    let result = DeepLinkHandler.parse(url)

    if case .invalid = result {
      // Expected
    } else {
      Issue.record("Expected invalid result for missing UUID")
    }
  }

  @Test
  func parse_extraPathComponents_returnsInvalid() throws {
    let url = try #require(URL(string: "dispatch://listing/\(UUID().uuidString)/extra"))

    let result = DeepLinkHandler.parse(url)

    if case .invalid = result {
      // Expected
    } else {
      Issue.record("Expected invalid result for extra path components")
    }
  }

  // MARK: - Route Conversion Tests

  @Test
  func toRoute_listingResult_returnsListingRoute() {
    let uuid = UUID()
    let result = DeepLinkHandler.ParseResult.listing(uuid)

    let route = DeepLinkHandler.toRoute(result)

    #expect(route == .listing(uuid))
  }

  @Test
  func toRoute_taskResult_returnsWorkItemRoute() {
    let uuid = UUID()
    let result = DeepLinkHandler.ParseResult.task(uuid)

    let route = DeepLinkHandler.toRoute(result)

    #expect(route == .workItem(.task(id: uuid)))
  }

  @Test
  func toRoute_propertyResult_returnsPropertyRoute() {
    let uuid = UUID()
    let result = DeepLinkHandler.ParseResult.property(uuid)

    let route = DeepLinkHandler.toRoute(result)

    #expect(route == .property(uuid))
  }

  @Test
  func toRoute_invalidResult_returnsNil() {
    let result = DeepLinkHandler.ParseResult.invalid(reason: "test")

    let route = DeepLinkHandler.toRoute(result)

    #expect(route == nil)
  }

  // MARK: - Convenience Method Tests

  @Test
  func route_validURL_returnsRoute() throws {
    let uuid = UUID()
    let url = try #require(URL(string: "dispatch://listing/\(uuid.uuidString)"))

    let route = DeepLinkHandler.route(from: url)

    #expect(route == .listing(uuid))
  }

  @Test
  func route_invalidURL_returnsNil() throws {
    let url = try #require(URL(string: "dispatch://listing/invalid"))

    let route = DeepLinkHandler.route(from: url)

    #expect(route == nil)
  }
}
