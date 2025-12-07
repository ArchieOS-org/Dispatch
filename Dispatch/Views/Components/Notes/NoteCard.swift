//
//  NoteCard.swift
//  Dispatch
//
//  Notes Component - Single note display card
//  Created by Claude on 2025-12-06.
//

import SwiftUI

/// A card displaying a single note with timestamp and content.
/// Supports edit/delete actions that appear on tap with spring animation.
struct NoteCard: View {
    let note: Note
    let author: User?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    @State private var showActions = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var timestampFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            // Header: Author + Timestamp
            HStack {
                if let author {
                    UserAvatar(user: author, size: .small)
                    Text(author.name)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.Text.secondary)
                }
                Spacer()
                Text(timestampFormatter.string(from: note.createdAt))
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.Text.tertiary)
            }

            // Content
            Text(note.content)
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.Text.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Edit indicator if edited
            if let editedAt = note.editedAt {
                Text("Edited \(timestampFormatter.string(from: editedAt))")
                    .font(DS.Typography.captionSecondary)
                    .foregroundColor(DS.Colors.Text.quaternary)
                    .italic()
            }

            // Action buttons (appear on tap)
            if showActions, onEdit != nil || onDelete != nil {
                HStack(spacing: DS.Spacing.sm) {
                    Spacer()
                    if let onEdit {
                        Button(action: onEdit) {
                            Image(systemName: DS.Icons.Action.edit)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.borderless)
                        .tint(DS.Colors.info)
                    }
                    if let onDelete {
                        Button(action: onDelete) {
                            Image(systemName: DS.Icons.Action.delete)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.borderless)
                        .tint(DS.Colors.destructive)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(DS.Spacing.cardPadding)
        .background(DS.Colors.Background.card)
        .cornerRadius(DS.Spacing.radiusCard)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Spacing.radiusCard)
                .stroke(DS.Colors.border, lineWidth: 1)
        )
        .dsShadow(DS.Shadows.card)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7)) {
                showActions.toggle()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Note by \(author?.name ?? "Unknown"): \(note.content)")
        .accessibilityHint(showActions ? "Actions visible. Tap to hide." : "Tap to show edit and delete options")
    }
}

// MARK: - Preview

#Preview("Note Card") {
    VStack(spacing: DS.Spacing.md) {
        NoteCard(
            note: Note(
                content: "This is a sample note with some text content that might span multiple lines.",
                createdBy: UUID(),
                parentType: .task,
                parentId: UUID()
            ),
            author: User(name: "John Doe", email: "john@example.com", userType: .admin),
            onEdit: { print("Edit") },
            onDelete: { print("Delete") }
        )

        NoteCard(
            note: Note(
                content: "Short note",
                createdBy: UUID(),
                parentType: .task,
                parentId: UUID()
            ),
            author: nil
        )
    }
    .padding()
}
