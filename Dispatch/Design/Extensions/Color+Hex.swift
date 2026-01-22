//
//  Color+Hex.swift
//  Dispatch
//
//  SwiftUI Color extension for hex string conversion.
//  Supports #RRGGBB and #AARRGGBB formats.
//

import SwiftUI

extension Color {

  // MARK: Lifecycle

  /// Creates a Color from a hex string.
  ///
  /// Supports formats:
  /// - `#RRGGBB` (e.g., "#4CAF50")
  /// - `#AARRGGBB` (e.g., "#FF4CAF50")
  /// - Without hash prefix (e.g., "4CAF50")
  ///
  /// Returns nil if the hex string is invalid.
  ///
  /// - Parameter hex: The hex color string.
  init?(hex: String) {
    // Remove # prefix if present
    var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if hexString.hasPrefix("#") {
      hexString.removeFirst()
    }

    // Validate hex length
    guard hexString.count == 6 || hexString.count == 8 else {
      return nil
    }

    // Parse hex value
    var hexValue: UInt64 = 0
    guard Scanner(string: hexString).scanHexInt64(&hexValue) else {
      return nil
    }

    // Extract components based on format
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    if hexString.count == 8 {
      // #AARRGGBB format
      alpha = Double((hexValue >> 24) & 0xFF) / 255.0
      red = Double((hexValue >> 16) & 0xFF) / 255.0
      green = Double((hexValue >> 8) & 0xFF) / 255.0
      blue = Double(hexValue & 0xFF) / 255.0
    } else {
      // #RRGGBB format
      alpha = 1.0
      red = Double((hexValue >> 16) & 0xFF) / 255.0
      green = Double((hexValue >> 8) & 0xFF) / 255.0
      blue = Double(hexValue & 0xFF) / 255.0
    }

    self.init(red: red, green: green, blue: blue, opacity: alpha)
  }

  // MARK: Internal

  /// Returns the hex string representation of this color.
  ///
  /// Format: `#RRGGBB` (without alpha if fully opaque) or `#AARRGGBB` (with alpha).
  ///
  /// Note: This requires resolving the color in an environment, so it returns
  /// an approximate value for dynamic colors.
  var hexString: String? {
    // Resolve color components using UIColor/NSColor bridge
    #if canImport(UIKit)
    guard
      let cgColor = UIColor(self).cgColor.converted(
        to: CGColorSpaceCreateDeviceRGB(),
        intent: .defaultIntent,
        options: nil
      ),
      let components = cgColor.components,
      components.count >= 3
    else {
      return nil
    }
    #elseif canImport(AppKit)
    guard
      let nsColor = NSColor(self).usingColorSpace(.deviceRGB)
    else {
      return nil
    }
    let cgColor = nsColor.cgColor
    guard
      let components = cgColor.components,
      components.count >= 3
    else {
      return nil
    }
    #else
    return nil
    #endif

    let red = Int(round(components[0] * 255))
    let green = Int(round(components[1] * 255))
    let blue = Int(round(components[2] * 255))
    let alpha = components.count >= 4 ? components[3] : 1.0

    if alpha < 1.0 {
      let alphaInt = Int(round(alpha * 255))
      return String(format: "#%02X%02X%02X%02X", alphaInt, red, green, blue)
    }
    return String(format: "#%02X%02X%02X", red, green, blue)
  }
}
