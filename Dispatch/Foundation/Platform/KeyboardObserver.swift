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
      object: nil,
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardWillHide),
      name: UIResponder.keyboardWillHideNotification,
      object: nil,
    )
    #endif
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
  private func keyboardWillHide(_: Notification) {
    overlayState?.show(reason: .keyboard)
  }
  #endif

}
