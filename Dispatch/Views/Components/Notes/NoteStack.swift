//
//  NoteStack.swift
//  Dispatch
//
//  Notes Component - flat, full-height list
//  Jobs-Standard v2: No dividers, clean spacing
//

import SwiftUI

/// A full-height flat list of notes sorted newest-first.
/// Clean spacing between notes, no dividers.
struct NoteStack: View {
    let notes: [Note]
    let userLookup: (UUID) -> User?
    var onDelete: ((Note) -> Void)?

    private var sortedNotes: [Note] {
        notes.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(sortedNotes) { note in
                NoteCard(
                    note: note,
                    author: userLookup(note.createdBy),
                    onDelete: onDelete != nil ? { onDelete?(note) } : nil
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Notes section with \(notes.count) note\(notes.count == 1 ? "" : "s")")
    }
}

// MARK: - Preview

#Preview("Note Stack") {
    let sampleNotes = (0..<6).map { i in
        Note(
            content: "Note \(i + 1): This is sample content for testing the note stack display.",
            createdBy: UUID(),
            parentType: .task,
            parentId: UUID()
        )
    }

    return ScrollView {
        VStack(spacing: DS.Spacing.xl) {
            Text("With Notes").font(DS.Typography.headline)
            NoteStack(
                notes: sampleNotes,
                userLookup: { _ in User(name: "Test User", email: "test@example.com", userType: .admin) },
                onDelete: { _ in }
            )

            Divider()

            Text("Empty State").font(DS.Typography.headline)
            Text("(Handled by composer)").font(DS.Typography.caption).foregroundColor(DS.Colors.Text.tertiary)
        }
        .padding()
    }
}
