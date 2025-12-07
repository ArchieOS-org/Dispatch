//
//  NoteStack.swift
//  Dispatch
//
//  Notes Component - 140pt cascading notes with shadow gradient
//  Created by Claude on 2025-12-06.
//
//  CRITICAL: This is THE DIFFERENTIATOR feature. Uses LinearGradient overlay
//  for shadow effect instead of .shadow() modifier because shadows get clipped
//  by the .clipped() modifier required for the fixed height container.
//

import SwiftUI

/// A fixed-height (140pt) cascading stack of notes with overflow indication.
/// Shows up to 5 most recent notes with cascading offset effect.
/// Uses gradient overlay (not .shadow()) to indicate more content above.
struct NoteStack: View {
    let notes: [Note]
    let userLookup: (UUID) -> User?
    var onEdit: ((Note) -> Void)?
    var onDelete: ((Note) -> Void)?

    private var displayNotes: [Note] {
        Array(notes.sorted { $0.createdAt > $1.createdAt }.prefix(5))
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Notes container - CLIPPED at 140pt
            VStack(spacing: DS.Spacing.stackSpacing) {
                ForEach(Array(displayNotes.enumerated()), id: \.element.id) { index, note in
                    NoteCard(
                        note: note,
                        author: userLookup(note.createdBy),
                        onEdit: onEdit != nil ? { onEdit?(note) } : nil,
                        onDelete: onDelete != nil ? { onDelete?(note) } : nil
                    )
                    .offset(y: CGFloat(index) * DS.Spacing.noteCascadeOffset)
                    .zIndex(Double(displayNotes.count - index)) // Top cards on top
                }
            }
            .frame(height: DS.Spacing.notesStackHeight, alignment: .top)
            .clipped()

            // Shadow gradient OUTSIDE clipping boundary to indicate overflow
            // CRITICAL: Use LinearGradient, NOT .shadow() - shadows get clipped!
            if notes.count > 3 {
                VStack {
                    Spacer()
                    DS.Shadows.notesOverflowGradient
                        .frame(height: DS.Spacing.shadowGradientHeight)
                        .allowsHitTesting(false)
                }
                .frame(height: DS.Spacing.notesStackHeight)
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
        .frame(height: DS.Spacing.notesStackHeight)
        .frame(maxWidth: .infinity)
        .background(DS.Colors.Background.secondary)
        .cornerRadius(DS.Spacing.radiusCard)
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
