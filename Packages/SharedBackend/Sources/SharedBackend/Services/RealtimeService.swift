//
//  RealtimeService.swift
//  SharedBackend
//
//  Provides access to Supabase Realtime functionality.
//

import Foundation
import Realtime
import Supabase

/// Provides access to Supabase Realtime functionality.
/// For complex channel configurations, access `realtimeClient` directly.
public struct RealtimeService: Sendable {
  private let client: SupabaseClient

  public init(client: SupabaseClient) {
    self.client = client
  }

  /// The underlying RealtimeClientV2 for direct access to all realtime features.
  /// Use this for creating channels with custom configuration closures.
  public var realtimeClient: RealtimeClientV2 {
    client.realtimeV2
  }

  /// Create a realtime channel with default configuration
  public func channel(_ topic: String) -> RealtimeChannelV2 {
    client.realtimeV2.channel(topic)
  }

  /// Remove a channel subscription
  public func removeChannel(_ channel: RealtimeChannelV2) async {
    await client.realtimeV2.removeChannel(channel)
  }

  /// Remove all channel subscriptions
  public func removeAllChannels() async {
    await client.realtimeV2.removeAllChannels()
  }
}
