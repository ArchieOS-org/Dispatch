//
//  NoteInputArea.swift
//  Dispatch
//
//  Notes Component - Always-visible inline composer
//  Jobs-Standard v2: Save on blur, conditional send icon, double-commit guard
//

import SwiftUI

/// An always-visible inline composer for creating notes.
/// - Placeholder: "Add a note…"
/// - Commit on blur (focus lost) or tap send icon
/// - Only clears on successful save
/// - Double-commit protection via isCommitting guard
struct NoteInputArea: View {
    @Binding var text: String
    var onSave: (String) -> Void

    @FocusState private var isFocused: Bool
    @State private var isCommitting = false

    private var hasValidInput: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                ZStack(alignment: .topLeading) {
                    // Placeholder (visible when empty and not focused)
                    if text.isEmpty && !isFocused {
                        Text("Add a note…")
                            .font(DS.Typography.body)
                            .foregroundColor(DS.Colors.Text.tertiary)
                            .padding(.horizontal, DS.Spacing.xs)
                            .padding(.vertical, DS.Spacing.sm)
                            .allowsHitTesting(false)
                    }

                    // TextEditor
                    TextEditor(text: $text)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.Text.primary)
                        .scrollContentBackground(.hidden)
                        .focused($isFocused)
                        .frame(minHeight: 40, maxHeight: 120)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Send button (appears only when valid input + focused)
                if hasValidInput && isFocused {
                    Button(action: commitNote) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(DS.Colors.accent)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(DS.Spacing.sm)
            .background(isFocused ? DS.Colors.Background.secondary : .clear)
            .cornerRadius(DS.Spacing.radiusCard)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
            .animation(.easeInOut(duration: 0.15), value: hasValidInput)
        }
        .onChange(of: isFocused) { _, newValue in
            // Commit on blur if there's valid input
            if !newValue && hasValidInput {
                commitNote()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Note input")
    }

    // MARK: - Commit

    private func commitNote() {
        // Double-commit guard
        guard !isCommitting else { return }
        guard hasValidInput else { return }

        isCommitting = true
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(content)
        text = ""  // Clear after save (local-first: insert always succeeds)
        isCommitting = false
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
                    onSave: { content in print("Saved: \(content)") }
                )

                Divider()

                Text("With Content")
                    .font(DS.Typography.caption)
                NoteInputArea(
                    text: .constant("This is a sample note with some content that the user has typed."),
                    onSave: { _ in }
                )
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
