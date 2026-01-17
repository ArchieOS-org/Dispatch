//
//  PlatformUtilities.swift
//  Dispatch
//
//  Created by Dispatch AI on 2025-12-28.
//

import SwiftUI

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

extension Image {
  init(platformImage: PlatformImage) {
    #if os(macOS)
    self.init(nsImage: platformImage)
    #else
    self.init(uiImage: platformImage)
    #endif
  }
}

extension PlatformImage {
  static func from(data: Data) -> PlatformImage? {
    PlatformImage(data: data)
  }
}

// MARK: - Copy Feedback Utilities

/// Provides cross-platform clipboard operations with visual feedback support.
/// Uses proper SwiftUI async patterns instead of DispatchQueue timing hacks.
enum CopyFeedback {

  /// Copies text to the system clipboard with optional haptic feedback.
  /// - Parameters:
  ///   - text: The text to copy
  ///   - label: Optional label for VoiceOver announcement (e.g., "Headline")
  static func copyToClipboard(_ text: String, label: String? = nil) {
    guard !text.isEmpty else { return }

    #if canImport(UIKit)
    UIPasteboard.general.string = text
    // Haptic feedback on iOS
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()
    // VoiceOver announcement
    if let label {
      UIAccessibility.post(notification: .announcement, argument: "\(label) copied")
    }
    #elseif canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #endif
  }

  /// Resets a boolean flag after a delay using proper async/await.
  /// - Parameters:
  ///   - flag: Binding to the boolean flag to reset
  ///   - delay: Duration to wait before resetting (default: 1.5 seconds)
  @MainActor
  static func resetFeedbackFlag(_ flag: Binding<Bool>, after delay: Duration = .seconds(1.5)) async {
    do {
      try await Task.sleep(for: delay)
      withAnimation(.easeInOut(duration: 0.2)) {
        flag.wrappedValue = false
      }
    } catch {
      // Task was cancelled - view likely disappeared, no action needed
    }
  }

  /// Standard delay for copy feedback reset (1.5 seconds)
  static let standardDelay: Duration = .seconds(1.5)

  /// Longer delay for copy feedback reset (2.0 seconds)
  static let longDelay: Duration = .seconds(2)
}
