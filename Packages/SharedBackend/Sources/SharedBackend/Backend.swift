//
//  Backend.swift
//  SharedBackend
//
//  Main entry point for the SharedBackend package.
//  Owns the SupabaseClient and provides typed access to services.
//

import Foundation
import OSLog
import Supabase

/// Main backend class that owns the Supabase client and provides access to all services.
public final class Backend: @unchecked Sendable {

  // MARK: Lifecycle

  /// Initialize the backend with a configuration.
  /// - Parameter config: Configuration containing Supabase URL and key
  /// - Throws: BackendError.invalidConfiguration if URL is invalid
  public init(config: BackendConfig) throws {
    #if DEBUG
    Self.logger.debug("Initializing Backend...")
    Self.logger.debug("URL: \(config.supabaseURL, privacy: .private)")
    Self.logger.debug("Anon Key (prefix): \(String(config.supabaseAnonKey.prefix(30)), privacy: .private)...")
    #endif

    guard let url = URL(string: config.supabaseURL) else {
      throw BackendError.invalidConfiguration("Invalid Supabase URL: \(config.supabaseURL)")
    }

    #if DEBUG
    Self.logger.debug("URL parsed successfully: \(url.absoluteString, privacy: .private)")
    #endif

    // Build custom headers
    var headers = config.customHeaders
    headers["x-app-name"] = config.appName

    client = SupabaseClient(
      supabaseURL: url,
      supabaseKey: config.supabaseAnonKey,
      options: SupabaseClientOptions(
        db: .init(schema: config.databaseSchema),
        auth: .init(
          flowType: .pkce,
          emitLocalSessionAsInitialSession: true
        ),
        global: .init(headers: headers)
      )
    )

    // Initialize services
    auth = AuthService(client: client)
    database = DatabaseService(client: client)
    storage = StorageService(client: client)
    realtime = RealtimeService(client: client)

    #if DEBUG
    Self.logger.info("Backend initialized successfully")
    Self.logger.debug("DB Schema: \(config.databaseSchema)")
    Self.logger.debug("Auth Flow: PKCE")
    Self.logger.debug("Custom Headers: \(headers.keys.joined(separator: ", "))")
    #endif
  }

  // MARK: Public

  /// The underlying Supabase client for direct access when needed.
  /// Prefer using the typed services (auth, database, storage, realtime) when possible.
  public let client: SupabaseClient

  /// Authentication service for sign in/out, session management
  public let auth: AuthService

  /// Database service for queries and RPC calls
  public let database: DatabaseService

  /// Storage service for file uploads/downloads
  public let storage: StorageService

  /// Realtime service for subscriptions and broadcasts
  public let realtime: RealtimeService

  // MARK: Private

  private static let logger = Logger(subsystem: "SharedBackend", category: "Backend")

}

// MARK: - Convenience Extensions

public extension Backend {
  /// Convenience access to auth client for cases where direct Auth API is needed
  var authClient: AuthClient {
    client.auth
  }

  /// Convenience access to realtime client for advanced realtime operations
  var realtimeClient: RealtimeClientV2 {
    client.realtimeV2
  }
}
