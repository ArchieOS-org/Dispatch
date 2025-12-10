//
//  ShakeGesture.swift
//  Dispatch
//
//  Created for Phase 1.3: Testing Infrastructure
//  Shake gesture detection for opening test harness
//

#if DEBUG
import SwiftUI
import UIKit

// MARK: - Shake Detection

/// Extension to detect shake gestures in UIWindow
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

// MARK: - Shake Gesture View Modifier

struct ShakeGestureModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                action()
            }
    }
}

// MARK: - View Extension

extension View {
    /// Perform an action when the device is shaken
    func onShake(perform action: @escaping () -> Void) -> some View {
        modifier(ShakeGestureModifier(action: action))
    }
}
#endif
