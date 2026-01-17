//
//  AuthService.swift
//  SharedBackend
//
//  Protocol and implementation for authentication operations.
//

import Foundation
import Supabase

/// Protocol defining authentication operations
public protocol AuthServiceProtocol: Sendable {
  /// Get the current session if authenticated
  func session() async throws -> Session

  /// Sign in with OAuth provider
  func signInWithOAuth(provider: Provider, redirectTo: URL?) async throws

  /// Sign out the current user
  func signOut() async throws

  /// Handle OAuth redirect URL
  func session(from url: URL) async throws -> Session
}

// MARK: - Default Implementation

/// Default implementation backed by Supabase Auth
public struct AuthService: AuthServiceProtocol {
  private let client: SupabaseClient

  public init(client: SupabaseClient) {
    self.client = client
  }

  public func session() async throws -> Session {
    try await client.auth.session
  }

  public func signInWithOAuth(provider: Provider, redirectTo: URL?) async throws {
    try await client.auth.signInWithOAuth(provider: provider, redirectTo: redirectTo)
  }

  public func signOut() async throws {
    try await client.auth.signOut()
  }

  public func session(from url: URL) async throws -> Session {
    try await client.auth.session(from: url)
  }
}
