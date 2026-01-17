//
//  DeepLinkHandler.swift
//  Dispatch
//
//  Created for Deep Linking Support
//

import Foundation
import OSLog

// MARK: - DeepLinkHandler

/// Handles parsing and routing of deep link URLs.
///
/// Supported URL patterns:
/// - `dispatch://listing/{uuid}` -> navigates to listing detail
/// - `dispatch://task/{uuid}` -> navigates to task detail
/// - `dispatch://property/{uuid}` -> navigates to property detail
enum DeepLinkHandler {

  // MARK: Internal

  /// Result of parsing a deep link URL
  enum ParseResult: Equatable {
    case listing(UUID)
    case task(UUID)
    case property(UUID)
    case invalid(reason: String)
  }

  /// The custom URL scheme for deep links
  static let scheme = "dispatch"

  /// Checks if a URL is a deep link (uses our scheme)
  static func isDeepLink(_ url: URL) -> Bool {
    url.scheme == scheme
  }

  /// Checks if a URL is an OAuth callback (Google sign-in redirect)
  static func isOAuthCallback(_ url: URL) -> Bool {
    url.scheme?.hasPrefix("com.googleusercontent.apps") ?? false
  }

  /// Parses a deep link URL and returns the appropriate route
  static func parse(_ url: URL) -> ParseResult {
    guard isDeepLink(url) else {
      return .invalid(reason: "URL scheme '\(url.scheme ?? "nil")' is not '\(scheme)'")
    }

    guard let host = url.host else {
      return .invalid(reason: "Missing host in URL")
    }

    // Parse path components (e.g., ["", "uuid"] from "/uuid")
    let pathComponents = url.pathComponents.filter { $0 != "/" }

    guard pathComponents.count == 1, let uuidString = pathComponents.first else {
      return .invalid(reason: "Expected single path component (UUID), got: \(pathComponents)")
    }

    guard let uuid = UUID(uuidString: uuidString) else {
      return .invalid(reason: "Invalid UUID format: '\(uuidString)'")
    }

    // Route based on host
    switch host {
    case "listing":
      return .listing(uuid)
    case "task":
      return .task(uuid)
    case "property":
      return .property(uuid)
    default:
      return .invalid(reason: "Unknown entity type: '\(host)'")
    }
  }

  /// Converts a parse result to an AppRoute (if valid)
  static func toRoute(_ result: ParseResult) -> AppRoute? {
    switch result {
    case .listing(let uuid):
      return .listing(uuid)
    case .task(let uuid):
      return .workItem(.task(id: uuid))
    case .property(let uuid):
      return .property(uuid)
    case .invalid:
      return nil
    }
  }

  /// Convenience: Parse URL and convert directly to AppRoute
  static func route(from url: URL) -> AppRoute? {
    let result = parse(url)
    if case .invalid(let reason) = result {
      logger.warning("Deep link parse failed: \(reason)")
    }
    return toRoute(result)
  }

  // MARK: Private

  private static let logger = Logger(subsystem: "Dispatch", category: "DeepLink")
}
