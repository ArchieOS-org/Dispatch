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

/// Lightweight fallback for keyboard detection.
/// iPhone only - iPad has inconsistent behavior with hardware/floating keyboards.
///
/// Attaches to AppOverlayState to hide floating buttons when keyboard appears.
@MainActor
final class KeyboardObserver: NSObject, ObservableObject {
    private var overlayState: AppOverlayState?
    private var isAttached = false

    /// Attaches the observer to an AppOverlayState instance.
    /// Only observes keyboard notifications on iPhone, not iPad.
    func attach(to overlayState: AppOverlayState) {
        guard !isAttached else { return }
        self.overlayState = overlayState
        self.isAttached = true

        #if os(iOS)
        // Only observe on iPhone, not iPad
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        #endif
    }
    
    #if os(iOS)
    @objc private func keyboardWillShow(_ notification: Notification) {
        overlayState?.hide(reason: .keyboard)
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        overlayState?.show(reason: .keyboard)
    }
    #endif
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
