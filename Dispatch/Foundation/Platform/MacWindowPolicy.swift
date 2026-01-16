//
//  MacWindowPolicy.swift
//  Dispatch
//
//  Created for Dispatch Layout Unification
//

import SwiftUI

#if os(macOS)
import AppKit

// MARK: - FullScreenObserver

/// Observable object that tracks whether the main window is in full-screen mode.
/// Uses NSWindow notifications to detect full-screen state changes.
@Observable
@MainActor
final class FullScreenObserver {
  private(set) var isFullScreen = false

  // Store observers in a nonisolated class to allow cleanup in deinit
  nonisolated private let observerStorage = ObserverStorage()

  // Thread-safety: ObserverStorage is only accessed from main thread (via main queue observers)
  // and deinit (which happens after all references are released). @unchecked is needed because
  // NSObjectProtocol is not Sendable, but our usage is safe.
  // swiftlint:disable:next no_unchecked_sendable
  private final class ObserverStorage: @unchecked Sendable {
    var willEnterObserver: NSObjectProtocol?
    var didExitObserver: NSObjectProtocol?

    func removeObservers() {
      if let observer = willEnterObserver {
        NotificationCenter.default.removeObserver(observer)
        willEnterObserver = nil
      }
      if let observer = didExitObserver {
        NotificationCenter.default.removeObserver(observer)
        didExitObserver = nil
      }
    }
  }

  init() {
    // Observe full-screen entry
    observerStorage.willEnterObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.willEnterFullScreenNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.isFullScreen = true
      }
    }

    // Observe full-screen exit
    observerStorage.didExitObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didExitFullScreenNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.isFullScreen = false
      }
    }
  }

  deinit {
    observerStorage.removeObservers()
  }
}

// MARK: - FullScreenEnvironmentKey

/// Environment key to expose full-screen state to SwiftUI views
private struct FullScreenEnvironmentKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  /// Whether the window is currently in macOS full-screen mode.
  /// Returns false on non-macOS platforms.
  var isFullScreen: Bool {
    get { self[FullScreenEnvironmentKey.self] }
    set { self[FullScreenEnvironmentKey.self] = newValue }
  }
}

// MARK: - MacWindowPolicy

/// A minimal window configuration policy that respects native macOS behavior
/// while enabling the standard modern "transparent titlebar" look.
///
/// Usage: Apply via `.background(MacWindowPolicy())` on the root view.
struct MacWindowPolicy: NSViewRepresentable {

  // MARK: Internal

  func makeNSView(context _: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async {
      if let window = view.window {
        configure(window)
      }
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context _: Context) {
    if let window = nsView.window {
      configure(window)
    }
  }

  // MARK: Private

  private func configure(_ window: NSWindow) {
    // Option A Strategy: Stop fighting the OS.
    // We do NOT remove the toolbar. We do NOT force title visibility constantly.

    // 1. Unified/Transparent Titlebar
    // This allows the window chrome to blend nicely, but we do NOT force content underneath
    // by removing .fullSizeContentView. This lets standard layout handle the top inset.
    window.titlebarAppearsTransparent = true

    // 2. Hide Native Title Text
    // We render a custom "Things 3" style left-aligned header in the content view on macOS.
    // So we hide the default center-aligned window title.
    window.titleVisibility = .hidden

    // 3. Enable Full-Size Content View
    // This allows sidebar and main content backgrounds to extend under the titlebar.
    // Content layout still respects safe areas; only backgrounds extend.
    if !window.styleMask.contains(.fullSizeContentView) {
      window.styleMask.insert(.fullSizeContentView)
    }
  }
}

// MARK: - FullScreenModifier

/// View modifier that injects full-screen state into the environment.
/// Creates and owns the FullScreenObserver.
private struct FullScreenModifier: ViewModifier {
  @State private var observer = FullScreenObserver()

  func body(content: Content) -> some View {
    content
      .environment(\.isFullScreen, observer.isFullScreen)
  }
}

extension View {
  /// Applies the standard Mac Window Policy and full-screen state observation.
  /// Should only be called once from the AppShell.
  func applyMacWindowPolicy() -> some View {
    background(MacWindowPolicy())
      .modifier(FullScreenModifier())
  }
}
#else
// MARK: - Non-macOS Environment Extension

extension EnvironmentValues {
  /// Whether the window is currently in macOS full-screen mode.
  /// Always returns false on non-macOS platforms.
  var isFullScreen: Bool {
    get { false }
    // swiftlint:disable:next unused_setter_value
    set { }
  }
}

extension View {
  func applyMacWindowPolicy() -> some View {
    self
  }
}
#endif
