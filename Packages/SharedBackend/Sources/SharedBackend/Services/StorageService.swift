//
//  StorageService.swift
//  SharedBackend
//
//  Protocol and implementation for storage operations.
//

import Foundation
import Storage
import Supabase

/// Protocol defining storage operations
public protocol StorageServiceProtocol: Sendable {
  /// Get a storage bucket reference
  func from(_ bucketId: String) -> StorageFileApi
}

// MARK: - Default Implementation

/// Default implementation backed by Supabase Storage
public struct StorageService: StorageServiceProtocol {
  private let client: SupabaseClient

  public init(client: SupabaseClient) {
    self.client = client
  }

  public func from(_ bucketId: String) -> StorageFileApi {
    client.storage.from(bucketId)
  }
}
