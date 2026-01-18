//
//  SyncStatus.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

/// Global sync status for SyncManager.
/// Error details live in SyncManager.lastSyncErrorMessage.
enum SyncStatus: Equatable {
  case idle // nothing happening
  case syncing // active sync in progress
  case ok(Date) // last successful sync time
  case error // some error exists; details in lastSyncErrorMessage
  case circuitBreakerOpen(remainingSeconds: Int) // circuit breaker tripped; sync paused
}
