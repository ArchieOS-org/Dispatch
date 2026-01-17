//
//  DatabaseService.swift
//  SharedBackend
//
//  Provides access to Supabase Database functionality.
//

import Foundation
import PostgREST
import Supabase

/// Provides access to Supabase Database functionality.
/// For RPC calls or advanced queries, use the underlying client directly.
public struct DatabaseService: Sendable {
  private let client: SupabaseClient

  public init(client: SupabaseClient) {
    self.client = client
  }

  /// Get a table reference for querying
  public func from(_ table: String) -> PostgrestQueryBuilder {
    client.from(table)
  }

  /// Call a database RPC function with parameters.
  /// Returns a builder that can be executed with `.execute()`.
  ///
  /// Example:
  /// ```swift
  /// let result: MyResultType = try await database.rpc("my_function", params: ["key": "value"])
  ///   .execute()
  ///   .value
  /// ```
  public func rpc<T: Encodable & Sendable>(_ fn: String, params: T) throws -> PostgrestFilterBuilder {
    try client.rpc(fn, params: params)
  }

  /// Call a database RPC function without parameters.
  public func rpc(_ fn: String) throws -> PostgrestFilterBuilder {
    try client.rpc(fn)
  }
}
