//
//  NoteStack.swift
//  Dispatch
//
//  Notes Component - flat, full-height list
//  Created by Claude on 2025-12-06.
//

import SwiftUI

/// A full-height flat list of notes sorted newest-first.
/// Shows all notes with dividers between them.
struct NoteStack: View {
    let notes: [Note]
    let userLookup: (UUID) -> User?
    var onEdit: ((Note) -> Void)?
    var onDelete: ((Note) -> Void)?

    private var sortedNotes: [Note] {
        notes.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(sortedNotes) { note in
                NoteCard(
                    note: note,
                    author: userLookup(note.createdBy),
                    onEdit: onEdit != nil ? { onEdit?(note) } : nil,
                    onDelete: onDelete != nil ? { onDelete?(note) } : nil
                )

                if note.id != sortedNotes.last?.id {
                    Divider()
                        .padding(.leading, DS.Spacing.md)
                }
            }

            if sortedNotes.isEmpty {
                NoteStack.emptyState
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Notes section with \(notes.count) note\(notes.count == 1 ? "" : "s")")
    }
}

// MARK: - Empty State

extension NoteStack {
    /// View to show when there are no notes
    static var emptyState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: DS.Icons.Entity.note)
                .font(.system(size: 32))
                .foregroundColor(DS.Colors.Text.tertiary)
            Text("No notes yet")
                .font(DS.Typography.bodySecondary)
                .foregroundColor(DS.Colors.Text.secondary)
            Text("Add a note to keep track of important details")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.Text.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, DS.Spacing.lg)
        .padding(.horizontal, DS.Spacing.md)
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
                onEdit: { _ in },
                onDelete: { _ in }
            )

            Divider()

            Text("Empty State").font(DS.Typography.headline)
            NoteStack.emptyState
        }
        .padding()
    }
}
