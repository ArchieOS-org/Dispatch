//
//  BackendConfig.swift
//  SharedBackend
//
//  Protocol for injecting Supabase configuration at runtime.
//  App must provide a concrete implementation with actual URL/key values.
//

import Foundation

/// Protocol defining the configuration required to initialize a Supabase backend.
/// Apps must provide a concrete implementation with their specific credentials.
public protocol BackendConfig: Sendable {
  /// The Supabase project URL (e.g., "https://xyzcompany.supabase.co")
  var supabaseURL: String { get }

  /// The Supabase anonymous/public API key
  var supabaseAnonKey: String { get }

  /// Optional: Database schema to use (defaults to "public")
  var databaseSchema: String { get }

  /// Optional: Custom headers to include with requests
  var customHeaders: [String: String] { get }

  /// Optional: App name for identification in request headers
  var appName: String { get }
}

// MARK: - Default Implementations

public extension BackendConfig {
  var databaseSchema: String { "public" }

  var customHeaders: [String: String] { [:] }

  var appName: String { "shared-backend-app" }
}
