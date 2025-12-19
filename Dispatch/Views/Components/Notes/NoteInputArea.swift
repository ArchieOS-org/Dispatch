//
//  NoteInputArea.swift
//  Dispatch
//
//  Notes Component - TextEditor with save/cancel buttons
//  Created by Claude on 2025-12-06.
//

import SwiftUI

/// A text input area for creating or editing notes.
/// Features placeholder text, dynamic height, and save/cancel actions.
struct NoteInputArea: View {
    @Binding var text: String
    var placeholder: String = "Add a note..."
    var onSave: () -> Void
    var onCancel: () -> Void

    @FocusState private var isFocused: Bool

    #if os(iOS)
    @EnvironmentObject private var overlayState: AppOverlayState
    #endif

    private var isValidInput: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Text Editor with placeholder
            ZStack(alignment: .topLeading) {
                // Placeholder - use opacity instead of conditional to avoid layout thrashing
                Text(placeholder)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.Text.placeholder)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, DS.Spacing.sm)
                    .allowsHitTesting(false)
                    .opacity(text.isEmpty ? 1 : 0)

                // Text Editor
                TextEditor(text: $text)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.Text.primary)
                    .scrollContentBackground(.hidden) // iOS 16+
                    .focused($isFocused)
                    .frame(
                        minHeight: DS.Spacing.noteInputMinHeight,
                        maxHeight: DS.Spacing.noteInputMaxHeight
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DS.Spacing.sm)
            .background(DS.Colors.Background.secondary)
            .cornerRadius(DS.Spacing.radiusCard)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Spacing.radiusCard)
                    .stroke(
                        isFocused ? DS.Colors.borderFocused : DS.Colors.border,
                        lineWidth: isFocused ? 2 : 1
                    )
            )

            // Action Buttons
            HStack(spacing: DS.Spacing.sm) {
                Button(action: {
                    isFocused = false
                    onCancel()
                }) {
                    Text("Cancel")
                        .font(DS.Typography.bodySecondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(DS.Colors.Text.secondary)

                Button(action: {
                    isFocused = false
                    onSave()
                }) {
                    Text("Save")
                        .font(DS.Typography.bodySecondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidInput)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Note input")
        #if os(iOS)
        .onChange(of: isFocused) { _, focused in
            if focused {
                overlayState.hide(reason: .textInput)
            } else {
                overlayState.show(reason: .textInput)
            }
        }
        #endif
    }
}

// MARK: - Preview

#Preview("Note Input Area") {
    struct PreviewWrapper: View {
        @State private var noteText = ""

        var body: some View {
            VStack(spacing: DS.Spacing.xl) {
                Text("Empty State")
                    .font(DS.Typography.caption)
                NoteInputArea(
                    text: $noteText,
                    onSave: { print("Save: \(noteText)") },
                    onCancel: { noteText = "" }
                )

                Divider()

                Text("With Content")
                    .font(DS.Typography.caption)
                NoteInputArea(
                    text: .constant("This is a sample note with some content that the user has typed."),
                    onSave: {},
                    onCancel: {}
                )
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
