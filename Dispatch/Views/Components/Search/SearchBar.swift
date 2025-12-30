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
/// - Automatic focus on appear
struct SearchBar: View {
    @Binding var text: String
    var showCancelButton: Bool = true
    var onCancel: () -> Void

    @FocusState private var isFocused: Bool

    #if os(iOS)
    // @EnvironmentObject private var overlayState: AppOverlayState // Removed
    #endif

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Search field
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DS.Colors.Text.tertiary)
                    .font(.body)

                TextField("Search tasks, activities, listings...", text: $text)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
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
        .onAppear {
            // Delay focus slightly for smoother animation, but wrap in transaction
            // to avoid triggering layout animations if inside a popover
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    isFocused = true
                }
            }
        }
        #if os(iOS)
        // One Boss Refactor: SearchBar is inside the overlay, no need to hide/show buttons manually.
        // The overlay presence itself hides the buttons in ContentView.
        // .onChange(of: isFocused) { ... } Removed
        #endif
    }
}

// MARK: - Preview

#Preview("Search Bar - Empty") {
    SearchBar(text: .constant(""), onCancel: {})
        .background(DS.Colors.Background.primary)
}

#Preview("Search Bar - With Text") {
    SearchBar(text: .constant("quarterly report"), onCancel: {})
        .background(DS.Colors.Background.primary)
}
