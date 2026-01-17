//
//  SearchBar.swift
//  Dispatch
//
//  Search input field with icon, clear button, and cancel action
//  Created by Claude on 2025-12-18.
//

import SwiftUI

/// A search bar component for the search overlay.
///
/// Features:
/// - Search icon
/// - Text input with placeholder
/// - Clear button (appears when text is present)
/// - Cancel button to dismiss
/// - Two focus modes: external binding (for SearchOverlay) or internal (standalone)
struct SearchBar: View {

  // MARK: Lifecycle

  /// External focus control (for SearchOverlay)
  init(
    text: Binding<String>,
    externalFocus: FocusState<Bool>.Binding,
    showCancelButton: Bool = true,
    onCancel: @escaping () -> Void
  ) {
    _text = text
    self.externalFocus = externalFocus
    self.showCancelButton = showCancelButton
    self.onCancel = onCancel
  }

  /// Internal focus control (standalone usage)
  init(
    text: Binding<String>,
    showCancelButton: Bool = true,
    onCancel: @escaping () -> Void
  ) {
    _text = text
    externalFocus = nil
    self.showCancelButton = showCancelButton
    self.onCancel = onCancel
  }

  // MARK: Internal

  @Binding var text: String

  var showCancelButton = true
  var onCancel: () -> Void

  var body: some View {
    HStack(spacing: DS.Spacing.sm) {
      // Search field
      HStack(spacing: DS.Spacing.sm) {
        Image(systemName: "magnifyingglass")
          .foregroundColor(DS.Colors.Text.tertiary)
          .font(.body)

        TextField("Search tasks, activities, listings...", text: $text)
          .textFieldStyle(.plain)
          .focused(externalFocus ?? $internalFocus)
          .submitLabel(.search)
          .autocorrectionDisabled()
        #if os(iOS)
          .textInputAutocapitalization(.never)
        #endif

        if !text.isEmpty {
          Button {
            text = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
            #if os(iOS)
              .foregroundColor(DS.Colors.Text.tertiary)
            #else
              .foregroundColor(Color.secondary)
            #endif
              .font(.body)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Clear search")
        }
      }
      .padding(.horizontal, DS.Spacing.md)
      .padding(.vertical, DS.Spacing.sm)
      .background(DS.Colors.Background.secondary)
      .cornerRadius(DS.Spacing.radiusMedium)

      // Cancel button
      if showCancelButton {
        Button("Cancel") {
          onCancel()
        }
        .foregroundColor(DS.Colors.accent)
        .accessibilityLabel("Cancel search")
      }
    }
    .padding(.horizontal, DS.Spacing.lg)
    .padding(.vertical, DS.Spacing.md)
    // No .onAppear auto-focus — parent controls focus timing when using external focus
  }

  // MARK: Private

  /// Internal focus for standalone usage
  @FocusState private var internalFocus: Bool

  /// External focus binding (nil = use internal)
  private let externalFocus: FocusState<Bool>.Binding?

}

// MARK: - Preview

#Preview("Search Bar - Empty") {
  SearchBar(text: .constant(""), onCancel: { })
    .background(DS.Colors.Background.primary)
}

#Preview("Search Bar - With Text") {
  SearchBar(text: .constant("quarterly report"), onCancel: { })
    .background(DS.Colors.Background.primary)
}
