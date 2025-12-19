//
//  HapticFeedback.swift
//  Dispatch
//
//  Wrapper for UIImpactFeedbackGenerator for haptic feedback
//

#if canImport(UIKit) && !os(macOS)
import UIKit

/// Utility for triggering haptic feedback
enum HapticFeedback {
    /// Light impact feedback - suitable for subtle confirmations
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Medium impact feedback - suitable for selections
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Heavy impact feedback - suitable for significant actions
    static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    /// Success notification feedback
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Warning notification feedback
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    /// Error notification feedback
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    /// Selection changed feedback - suitable for picker/filter changes
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
#else
/// No-op haptic feedback for platforms without haptic support (macOS)
enum HapticFeedback {
    static func light() {}
    static func medium() {}
    static func heavy() {}
    static func success() {}
    static func warning() {}
    static func error() {}
    static func selection() {}
}
#endif
