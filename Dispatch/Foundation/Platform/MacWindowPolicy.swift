//
//  MacWindowPolicy.swift
//  Dispatch
//
//  Created for Dispatch Layout Unification
//

import SwiftUI

#if os(macOS)
import AppKit

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

  /// Sets the visibility of the traffic light buttons (close, minimize, zoom).
  /// - Parameters:
  ///   - hidden: Whether to hide the traffic lights
  ///   - window: The window containing the traffic lights
  static func setTrafficLightsHidden(_ hidden: Bool, for window: NSWindow) {
    [
      NSWindow.ButtonType.closeButton,
      NSWindow.ButtonType.miniaturizeButton,
      NSWindow.ButtonType.zoomButton
    ].forEach { buttonType in
      window.standardWindowButton(buttonType)?.isHidden = hidden
    }
  }

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

    // 1a. Window Transparency for Material Backgrounds
    // Required for NSVisualEffectView/Material to show translucency.
    // Without these, materials render as opaque colored backgrounds.
    window.isOpaque = false
    window.backgroundColor = .clear

    // 1b. Unified/Transparent Titlebar
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

    // 4. Remove titlebar separator line
    // This eliminates the thin line between titlebar and content for a cleaner look.
    window.titlebarSeparatorStyle = .none
  }

}

// MARK: - FullScreenTrafficLightController

/// Coordinator that manages traffic light visibility based on mouse position in full-screen mode.
/// Also handles making the toolbar background transparent in full-screen to match windowed mode.
/// Uses local event monitor to track mouse movement within the app's windows.
// swiftlint:disable no_direct_standard_out_logs
private final class FullScreenTrafficLightCoordinator {

  // MARK: Lifecycle

  init() {
    setupNotifications()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    stopMouseMonitoring()
  }

  // MARK: Internal

  /// Height of the titlebar hover zone (from top of window)
  static let titlebarHoverHeight: CGFloat = 52

  weak var window: NSWindow?

  func attach(to window: NSWindow) {
    self.window = window
    updateForFullScreenState()
  }

  // MARK: Private

  // MARK: - Toolbar Background Transparency (Experimental)

  /// Debug flag - set to true to see view hierarchy in console
  private static let debugLogging = true

  private var isFullScreen = false
  private var trafficLightsVisible = true
  private var mouseMonitor: Any?
  /// Tracks NSVisualEffectViews we've modified so we can restore them
  private var modifiedEffectViews: [NSVisualEffectView] = []

  private func setupNotifications() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowWillEnterFullScreen),
      name: NSWindow.willEnterFullScreenNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidEnterFullScreen),
      name: NSWindow.didEnterFullScreenNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidExitFullScreen),
      name: NSWindow.didExitFullScreenNotification,
      object: nil
    )
  }

  @objc
  private func windowWillEnterFullScreen(_ notification: Notification) {
    guard
      let notificationWindow = notification.object as? NSWindow,
      notificationWindow == window
    else { return }
    isFullScreen = true
    // Hide traffic lights when entering full-screen
    setTrafficLightsVisible(false)
    startMouseMonitoring()
  }

  @objc
  private func windowDidEnterFullScreen(_ notification: Notification) {
    guard
      let notificationWindow = notification.object as? NSWindow,
      notificationWindow == window
    else { return }
    // Make toolbar background transparent after full-screen transition completes
    // Try multiple delays to catch any late view hierarchy changes
    //
    // NOTE: DispatchQueue.main.asyncAfter is INTENTIONALLY used here.
    // This is legitimate AppKit/NSWindow interop, NOT a SwiftUI timing hack.
    //
    // Why we cannot use Task.sleep or SwiftUI patterns:
    // 1. Full-screen transitions involve window server coordination that SwiftUI cannot observe
    // 2. NSWindow view hierarchy is rebuilt asynchronously during full-screen transition
    // 3. The toolbar's NSVisualEffectView instances are created/destroyed by AppKit, not SwiftUI
    // 4. No notification or delegate callback exists for "toolbar view hierarchy settled"
    // 5. Multiple attempts are needed because AppKit may create views at different times
    //
    // This code runs in an NSNotification observer (Objective-C runtime context),
    // and the delays are coordinated with AppKit's internal window management.

    // APPROACH 4: Try different delays
    // First attempt at 0.5s - catches most transitions
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      if Self.debugLogging {
        print("DEBUG: --- ATTEMPT 1 (0.5s delay) ---")
      }
      self?.makeToolbarBackgroundTransparent()
    }

    // Second attempt at 1.0s in case views are created later by AppKit
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
      if Self.debugLogging {
        print("DEBUG: --- ATTEMPT 2 (1.0s delay) ---")
      }
      self?.makeToolbarBackgroundTransparent()
    }
  }

  @objc
  private func windowDidExitFullScreen(_ notification: Notification) {
    guard
      let notificationWindow = notification.object as? NSWindow,
      notificationWindow == window
    else { return }
    isFullScreen = false
    // Show traffic lights when exiting full-screen
    setTrafficLightsVisible(true)
    stopMouseMonitoring()
    // Restore toolbar background (the window reconfiguration typically handles this,
    // but we clear our tracking array to be safe)
    restoreToolbarBackground()
  }

  private func updateForFullScreenState() {
    guard let window else { return }
    isFullScreen = window.styleMask.contains(.fullScreen)
    if isFullScreen {
      setTrafficLightsVisible(false)
      startMouseMonitoring()
    } else {
      setTrafficLightsVisible(true)
      stopMouseMonitoring()
    }
  }

  private func startMouseMonitoring() {
    guard mouseMonitor == nil else { return }

    // Use local monitor for events within our app
    mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
      self?.handleMouseMoved(event)
      return event
    }
  }

  private func stopMouseMonitoring() {
    if let monitor = mouseMonitor {
      NSEvent.removeMonitor(monitor)
      mouseMonitor = nil
    }
  }

  private func handleMouseMoved(_ event: NSEvent) {
    guard isFullScreen, let window, event.window == window else { return }

    let locationInWindow = event.locationInWindow
    let windowHeight = window.frame.height
    let titlebarMinY = windowHeight - Self.titlebarHoverHeight

    let mouseInTitlebar = locationInWindow.y >= titlebarMinY

    if mouseInTitlebar, !trafficLightsVisible {
      setTrafficLightsVisible(true)
    } else if !mouseInTitlebar, trafficLightsVisible {
      setTrafficLightsVisible(false)
    }
  }

  private func setTrafficLightsVisible(_ visible: Bool) {
    guard let window, trafficLightsVisible != visible else { return }
    trafficLightsVisible = visible
    MacWindowPolicy.setTrafficLightsHidden(!visible, for: window)
  }

  /// Makes the toolbar background transparent in full-screen mode.
  /// This is an experimental approach that manipulates NSVisualEffectView instances
  /// in the titlebar/toolbar area. May break with future macOS updates.
  private func makeToolbarBackgroundTransparent() {
    guard let window else { return }

    if Self.debugLogging {
      print("DEBUG: ========== FULL-SCREEN TOOLBAR TRANSPARENCY ==========")
      print("DEBUG: Window frame: \(window.frame)")
      print("DEBUG: Window styleMask: \(window.styleMask)")
      print("DEBUG: Window toolbar: \(String(describing: window.toolbar))")
      print("DEBUG: Window toolbarStyle: \(window.toolbarStyle.rawValue)")
      print("DEBUG: Content view: \(String(describing: window.contentView))")

      // Print the entire view hierarchy from themeFrame
      if let themeFrame = window.contentView?.superview {
        print("DEBUG: --- FULL VIEW HIERARCHY FROM THEME FRAME ---")
        printViewHierarchy(themeFrame, indent: 0)
      }
    }

    // Clear any previously tracked views
    modifiedEffectViews.removeAll()

    // APPROACH 1: Set toolbarStyle (may affect full-screen rendering)
    // Try .unified which integrates toolbar with titlebar
    window.toolbarStyle = .unified

    // APPROACH 2a: Original approach - from close button
    if
      let closeButton = window.standardWindowButton(.closeButton),
      let titlebarContainer = closeButton.superview?.superview
    {
      if Self.debugLogging {
        print("DEBUG: --- APPROACH 2a: From close button ---")
        print("DEBUG: Close button: \(closeButton)")
        print("DEBUG: Close button superview: \(String(describing: closeButton.superview))")
        print("DEBUG: Titlebar container (superview.superview): \(titlebarContainer)")
      }
      makeVisualEffectsTransparent(in: titlebarContainer, approach: "2a-closeButton")
    }

    // APPROACH 2b: Traverse from contentView's superview (themeFrame)
    if let themeFrame = window.contentView?.superview {
      if Self.debugLogging {
        print("DEBUG: --- APPROACH 2b: From theme frame ---")
        print("DEBUG: Theme frame: \(themeFrame) - type: \(type(of: themeFrame))")
      }
      // Look for titlebar container by class name
      if let titlebarContainer = findTitlebarContainer(in: themeFrame) {
        if Self.debugLogging {
          print("DEBUG: Found titlebar container: \(titlebarContainer) - type: \(type(of: titlebarContainer))")
        }
        makeVisualEffectsTransparent(in: titlebarContainer, approach: "2b-titlebarContainer")
      }
    }

    // APPROACH 2c: Find ALL visual effect views in the entire window
    if let themeFrame = window.contentView?.superview {
      let allEffectViews = findAllVisualEffectViews(in: themeFrame)
      if Self.debugLogging {
        print("DEBUG: --- APPROACH 2c: All NSVisualEffectViews in window ---")
        print("DEBUG: Found \(allEffectViews.count) NSVisualEffectViews total")
        for (index, view) in allEffectViews.enumerated() {
          print(
            "DEBUG:   [\(index)] frame: \(view.frame), material: \(view.material.rawValue), blendingMode: \(view.blendingMode.rawValue)"
          )
        }
      }

      // Only modify views that appear to be in the titlebar area (top of window)
      let windowHeight = window.frame.height
      for effectView in allEffectViews {
        let frameInWindow = effectView.convert(effectView.bounds, to: nil)
        let isInTitlebarArea = frameInWindow.minY > (windowHeight - 100)

        if Self.debugLogging {
          print("DEBUG:   Checking view at \(frameInWindow), isInTitlebarArea: \(isInTitlebarArea)")
        }

        if isInTitlebarArea {
          // APPROACH 3: Try setting material instead of alpha
          // This may work better than hiding the view entirely
          effectView.material = .windowBackground
          effectView.blendingMode = .behindWindow
          effectView.state = .inactive
          effectView.isEmphasized = false

          // Also try alpha = 0 as backup
          effectView.alphaValue = 0

          modifiedEffectViews.append(effectView)

          if Self.debugLogging {
            print("DEBUG:   MODIFIED view at \(frameInWindow)")
          }
        }
      }
    }

    if Self.debugLogging {
      print("DEBUG: Total modified views: \(modifiedEffectViews.count)")
      print("DEBUG: ========== END TOOLBAR TRANSPARENCY ==========")
    }
  }

  /// Finds the titlebar container view by traversing the hierarchy and looking for class names containing "Titlebar"
  private func findTitlebarContainer(in view: NSView) -> NSView? {
    let typeName = String(describing: type(of: view))
    if typeName.contains("Titlebar") {
      return view
    }
    for subview in view.subviews {
      if let found = findTitlebarContainer(in: subview) {
        return found
      }
    }
    return nil
  }

  /// Finds all NSVisualEffectView instances in the view hierarchy
  private func findAllVisualEffectViews(in view: NSView) -> [NSVisualEffectView] {
    var effectViews: [NSVisualEffectView] = []
    if let effectView = view as? NSVisualEffectView {
      effectViews.append(effectView)
    }
    for subview in view.subviews {
      effectViews.append(contentsOf: findAllVisualEffectViews(in: subview))
    }
    return effectViews
  }

  /// Debug: Print the view hierarchy
  private func printViewHierarchy(_ view: NSView, indent: Int) {
    let prefix = String(repeating: "  ", count: indent)
    let typeName = String(describing: type(of: view))
    var extras = ""
    if let effectView = view as? NSVisualEffectView {
      extras =
        " [material:\(effectView.material.rawValue), blending:\(effectView.blendingMode.rawValue), alpha:\(effectView.alphaValue)]"
    }
    print("\(prefix)\(typeName) - frame: \(view.frame)\(extras)")
    for subview in view.subviews {
      printViewHierarchy(subview, indent: indent + 1)
    }
  }

  /// Recursively traverses the view hierarchy and makes NSVisualEffectView instances transparent.
  private func makeVisualEffectsTransparent(in view: NSView, approach: String) {
    if let effectView = view as? NSVisualEffectView {
      if Self.debugLogging {
        print(
          "DEBUG: [\(approach)] Found NSVisualEffectView: frame=\(effectView.frame), material=\(effectView.material.rawValue)"
        )
      }
      effectView.alphaValue = 0
      modifiedEffectViews.append(effectView)
    }
    for subview in view.subviews {
      makeVisualEffectsTransparent(in: subview, approach: approach)
    }
  }

  /// Restores the toolbar background after exiting full-screen.
  /// The window reconfiguration typically handles this, but we track modified views
  /// in case manual restoration is needed.
  private func restoreToolbarBackground() {
    for effectView in modifiedEffectViews {
      effectView.alphaValue = 1
      effectView.state = .followsWindowActiveState
    }
    modifiedEffectViews.removeAll()
  }
}

// swiftlint:enable no_direct_standard_out_logs

// MARK: - FullScreenTrafficLightView

/// NSView that hosts the traffic light coordinator and attaches it to the window.
private final class FullScreenTrafficLightView: NSView {

  // MARK: Lifecycle

  override init(frame frameRect: NSRect) {
    coordinator = FullScreenTrafficLightCoordinator()
    super.init(frame: frameRect)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: Internal

  let coordinator: FullScreenTrafficLightCoordinator

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if let window {
      coordinator.attach(to: window)
    }
  }
}

// MARK: - FullScreenTrafficLightModifier

/// NSViewRepresentable that embeds the traffic light controller.
private struct FullScreenTrafficLightModifier: NSViewRepresentable {
  func makeNSView(context _: Context) -> FullScreenTrafficLightView {
    FullScreenTrafficLightView(frame: .zero)
  }

  func updateNSView(_: FullScreenTrafficLightView, context _: Context) {
    // No updates needed - the coordinator manages itself via notifications
  }
}

// MARK: - FullScreenModifier

/// View modifier that injects full-screen state into the environment.
/// Uses onReceive for notification-driven state updates that properly trigger SwiftUI view invalidation.
private struct FullScreenModifier: ViewModifier {
  @State private var isFullScreen = false

  func body(content: Content) -> some View {
    content
      .environment(\.isFullScreen, isFullScreen)
      .background(FullScreenTrafficLightModifier())
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { _ in
        isFullScreen = true
      }
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
        isFullScreen = false
      }
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
