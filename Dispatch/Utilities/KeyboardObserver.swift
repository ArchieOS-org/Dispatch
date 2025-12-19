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
final class KeyboardObserver: ObservableObject {
    private var overlayState: AppOverlayState?

    /// Attaches the observer to an AppOverlayState instance.
    /// Only observes keyboard notifications on iPhone, not iPad.
    func attach(to overlayState: AppOverlayState) {
        self.overlayState = overlayState

        #if os(iOS)
        // Only observe on iPhone, not iPad
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.overlayState?.hide(reason: .keyboard)
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.overlayState?.show(reason: .keyboard)
            }
        }
        #endif
    }
}
