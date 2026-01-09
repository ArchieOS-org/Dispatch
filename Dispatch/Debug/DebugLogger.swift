//
//  DebugLogger.swift
//  Dispatch
//
//  Created for Phase 1.3: Comprehensive DEBUG-only logging
//  Completely stripped in Release builds for zero overhead
//

import Combine
import Foundation
import os.log

#if DEBUG

/// Centralized DEBUG-only logger for extremely verbose sync debugging
/// All logging is compile-time stripped in Release builds
@MainActor
final class DebugLogger: ObservableObject {

  // MARK: Lifecycle

  private init() {
    log("DebugLogger initialized", category: .sync)
  }

  // MARK: Internal

  enum Category: String, CaseIterable {
    case realtime = "REALTIME"
    case channel = "CHANNEL"
    case sync = "SYNC"
    case websocket = "WEBSOCKET"
    case event = "EVENT"
    case error = "ERROR"
    case auth = "AUTH"

    var emoji: String {
      switch self {
      case .realtime: "📡"
      case .channel: "📺"
      case .sync: "🔄"
      case .websocket: "🔌"
      case .event: "⚡️"
      case .error: "❌"
      case .auth: "🔑"
      }
    }
  }

  static let shared = DebugLogger()

  @Published private(set) var logs = [DebugLogEntry]()

  func log(
    _ message: String,
    category: Category = .sync,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    let entry = DebugLogEntry(
      timestamp: Date(),
      category: category,
      message: message,
      file: (file as NSString).lastPathComponent,
      function: function,
      line: line
    )

    // Add to buffer for in-app display
    logs.append(entry)
    if logs.count > maxLogEntries {
      logs.removeFirst(logs.count - maxLogEntries)
    }

    // Print to console with detailed formatting
    let timestamp = Self.isoFormatter.string(from: entry.timestamp)
    let logLine = "[\(timestamp)] [\(category.emoji) \(category.rawValue)] \(message)"
    consoleLog.debug("\(logLine)")

    // Also log to os_log for Console.app filtering
    switch category {
    case .realtime: realtimeLog.debug("\(message)")
    case .channel: channelLog.debug("\(message)")
    case .sync: syncLog.debug("\(message)")
    case .websocket: websocketLog.debug("\(message)")
    case .event: realtimeLog.info("\(message)")
    case .error: realtimeLog.error("\(message)")
    case .auth: syncLog.debug("\(message)")
    }
  }

  func error(
    _ message: String,
    error: Error? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    var fullMessage = message
    if let error {
      fullMessage += "\n  Error: \(error)"
      fullMessage += "\n  LocalizedDescription: \(error.localizedDescription)"
      if let nsError = error as NSError? {
        fullMessage += "\n  Domain: \(nsError.domain), Code: \(nsError.code)"
        if !nsError.userInfo.isEmpty {
          fullMessage += "\n  UserInfo: \(nsError.userInfo)"
        }
      }
    }
    log(fullMessage, category: .error, file: file, function: function, line: line)
  }

  func startTiming(_ operation: String) {
    operationStartTimes[operation] = Date()
    log("⏱️ START: \(operation)", category: .sync)
  }

  func endTiming(_ operation: String) {
    guard let startTime = operationStartTimes[operation] else {
      log("⏱️ END: \(operation) (no start time recorded)", category: .sync)
      return
    }
    let duration = Date().timeIntervalSince(startTime)
    operationStartTimes.removeValue(forKey: operation)
    log("⏱️ END: \(operation) - Duration: \(String(format: "%.3f", duration))s", category: .sync)
  }

  func logWebSocketStatus(_ status: String, url: URL? = nil) {
    var message = "Socket status: \(status)"
    if let url {
      message += "\n  URL: \(url.absoluteString)"
    }
    log(message, category: .websocket)
  }

  func logChannelStatus(_ channelName: String, status: String, details: String? = nil) {
    var message = "Channel '\(channelName)' status: \(status)"
    if let details {
      message += "\n  Details: \(details)"
    }
    log(message, category: .channel)
  }

  func logSubscriptionConfig(table: String, schema: String, filter: String? = nil) {
    var message = "Subscribing to postgres changes:"
    message += "\n  Schema: \(schema)"
    message += "\n  Table: \(table)"
    if let filter {
      message += "\n  Filter: \(filter)"
    }
    log(message, category: .channel)
  }

  func logEventReceived(table: String, action: String, payload: Any?) {
    var message = "📥 EVENT RECEIVED:"
    message += "\n  Table: \(table)"
    message += "\n  Action: \(action)"
    if let payload {
      message += "\n  Payload: \(String(describing: payload))"
    }
    log(message, category: .event)
  }

  func logForAwaitLoop(entering: Bool, table: String) {
    let state = entering ? "ENTERING" : "EXITING"
    log("🔁 for-await loop \(state) for table: \(table)", category: .event)
  }

  func logSyncOperation(operation: String, table: String, count: Int, details: String? = nil) {
    var message = "\(operation) - \(table): \(count) entities"
    if let details {
      message += " (\(details))"
    }
    log(message, category: .sync)
  }

  func clearLogs() {
    logs.removeAll()
    log("Logs cleared", category: .sync)
  }

  func exportLogs() -> String {
    logs.map { entry in
      let timestamp = Self.isoFormatter.string(from: entry.timestamp)
      return "[\(timestamp)] [\(entry.category.rawValue)] \(entry.message)"
    }.joined(separator: "\n")
  }

  // MARK: Private

  private static let isoFormatter = ISO8601DateFormatter()

  private let maxLogEntries = 500

  private let realtimeLog = Logger(subsystem: "com.dispatch.app", category: "Realtime")
  private let channelLog = Logger(subsystem: "com.dispatch.app", category: "Channel")
  private let syncLog = Logger(subsystem: "com.dispatch.app", category: "Sync")
  private let websocketLog = Logger(subsystem: "com.dispatch.app", category: "WebSocket")
  private let consoleLog = Logger(subsystem: "com.dispatch.app", category: "DebugConsole")

  private var operationStartTimes = [String: Date]()

}

// MARK: - Log Entry Model

struct DebugLogEntry: Identifiable {
  let id = UUID()
  let timestamp: Date
  let category: DebugLogger.Category
  let message: String
  let file: String
  let function: String
  let line: Int

  var isError: Bool {
    category == .error
  }
}

/// Quick access to the debug logger
var debugLog: DebugLogger {
  DebugLogger.shared
}

#else

// =============================================================================
// RELEASE BUILD STUBS - Completely stripped by compiler (zero overhead)
// =============================================================================

@MainActor
final class DebugLogger: ObservableObject {

  // MARK: Lifecycle

  private init() { }

  // MARK: Internal

  enum Category: String, CaseIterable {
    case realtime
    case channel
    case sync
    case websocket
    case event
    case error
    case auth

    var emoji: String {
      ""
    }
  }

  static let shared = DebugLogger()

  @Published var logs = [DebugLogEntry]()

  @inlinable
  func log(
    _: String,
    category _: Category = .sync,
    file _: String = #file,
    function _: String = #function,
    line _: Int = #line
  ) { }
  @inlinable
  func error(
    _: String,
    error _: Error? = nil,
    file _: String = #file,
    function _: String = #function,
    line _: Int = #line
  ) { }
  @inlinable
  func startTiming(_: String) { }
  @inlinable
  func endTiming(_: String) { }
  @inlinable
  func logWebSocketStatus(_: String, url _: URL? = nil) { }
  @inlinable
  func logChannelStatus(_: String, status _: String, details _: String? = nil) { }
  @inlinable
  func logSubscriptionConfig(table _: String, schema _: String, filter _: String? = nil) { }
  @inlinable
  func logEventReceived(table _: String, action _: String, payload _: Any?) { }
  @inlinable
  func logForAwaitLoop(entering _: Bool, table _: String) { }
  @inlinable
  func logSyncOperation(operation _: String, table _: String, count _: Int, details _: String? = nil) { }
  @inlinable
  func clearLogs() { }
  @inlinable
  func exportLogs() -> String {
    ""
  }
}

struct DebugLogEntry: Identifiable {
  let id = UUID()
  let timestamp = Date()
  let category = DebugLogger.Category.sync
  let message = ""
  let file = ""
  let function = ""
  let line = 0

  var isError: Bool {
    false
  }
}

var debugLog: DebugLogger {
  DebugLogger.shared
}

#endif
