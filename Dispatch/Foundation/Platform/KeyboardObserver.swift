//
//  KeyboardObserver.swift
//  Dispatch
//
//  Lightweight fallback for keyboard detection (iPhone only)
//

import Combine
import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - KeyboardObserver

/// Lightweight fallback for keyboard detection.
/// iPhone only - iPad has inconsistent behavior with hardware/floating keyboards.
///
/// Attaches to AppOverlayState to hide floating buttons when keyboard appears.
@MainActor
final class KeyboardObserver: NSObject, ObservableObject {

  // MARK: Lifecycle

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // MARK: Internal

  /// Attaches the observer to an AppOverlayState instance.
  /// Only observes keyboard notifications on iPhone, not iPad.
  func attach(to overlayState: AppOverlayState) {
    guard !isAttached else { return }
    // Preview Isolation: Do not observe keyboard in preview mode
    if overlayState.mode == .preview { return }

    self.overlayState = overlayState
    isAttached = true

    #if os(iOS)
    // Only observe on iPhone, not iPad
    guard UIDevice.current.userInterfaceIdiom == .phone else { return }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardWillShow),
      name: UIResponder.keyboardWillShowNotification,
      object: nil
    )

    // Use keyboardDidHide for precise timing — buttons appear only when keyboard is fully gone
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardDidHide),
      name: UIResponder.keyboardDidHideNotification,
      object: nil
    )
    #endif
  }

  /// Detaches and removes all observers
  func detach() {
    guard isAttached else { return }
    NotificationCenter.default.removeObserver(self)
    overlayState = nil
    isAttached = false
  }

  // MARK: Private

  private var overlayState: AppOverlayState?
  private var isAttached = false

  #if os(iOS)
  @objc
  private func keyboardWillShow(_: Notification) {
    overlayState?.hide(reason: .keyboard)
  }

  @objc
  private func keyboardDidHide(_: Notification) {
    // Keyboard is fully gone — safe to show buttons
    overlayState?.show(reason: .keyboard)
  }
  #endif

}
