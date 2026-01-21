//
//  String+TitleCase.swift
//  Dispatch
//
//  String extension for title case formatting of address fields.
//

import Foundation

extension String {
  /// Converts the string to title case (first letter of each word capitalized).
  ///
  /// Handles common small words (of, the, and, in, at, for, to) by keeping them
  /// lowercase unless they appear at the start of the string.
  ///
  /// - Returns: The title-cased string, or empty string if input is empty.
  ///
  /// Examples:
  /// - "san francisco" -> "San Francisco"
  /// - "SAN FRANCISCO" -> "San Francisco"
  /// - "123 main street" -> "123 Main Street"
  /// - "city of toronto" -> "City of Toronto"
  /// - "" -> ""
  func titleCased() -> String {
    guard !isEmpty else { return "" }

    // Small words that should stay lowercase (except at start)
    let smallWords: Set<String> = ["of", "the", "and", "in", "at", "for", "to", "a", "an"]

    let words = lowercased().split(separator: " ")

    let titleCasedWords = words.enumerated().map { index, word -> String in
      let wordString = String(word)

      // Keep small words lowercase (except at start)
      if index != 0, smallWords.contains(wordString) {
        return wordString
      }

      // Capitalize only the first character, keep rest lowercase
      // This avoids Swift's .capitalized which uppercases letters after digits (e.g., "2b" -> "2B")
      return wordString.prefix(1).uppercased() + wordString.dropFirst()
    }

    return titleCasedWords.joined(separator: " ")
  }
}
