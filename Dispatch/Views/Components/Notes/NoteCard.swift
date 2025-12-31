//
//  NoteCard.swift
//  Dispatch
//
//  Notes Component - Single note display card
//  Jobs-Standard v2: No avatar, compact timestamp, balanced typography
//

import SwiftUI

/// A card displaying a single note with author and compact timestamp.
/// Clean, minimal design—no avatars, no dividers.
struct NoteCard: View {
    let note: Note
    let author: User?
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            // Header: Author (semibold) + compact timestamp (tertiary, right)
            HStack {
                Text(author?.name ?? "Unknown")
                    .font(DS.Typography.bodySecondary.weight(.semibold))
                    .foregroundColor(DS.Colors.Text.primary)
                Spacer()
                Text(compactTimestamp(note.createdAt))
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.Text.tertiary)
            }

            // Content
            Text(note.content)
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.Text.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            // Edited indicator (if applicable)
            if let editedAt = note.editedAt {
                Text("Edited \(compactTimestamp(editedAt))")
                    .font(DS.Typography.captionSecondary)
                    .foregroundColor(DS.Colors.Text.quaternary)
                    .italic()
            }
        }
        .padding(.vertical, DS.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Note by \(author?.name ?? "Unknown"): \(note.content)")
    }

    // MARK: - Compact Timestamp

    /// Returns human-readable relative time: "now", "5m", "2h", "Dec 31", etc.
    private func compactTimestamp(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        // < 60 seconds
        if interval < 60 {
            return "now"
        }
        // < 60 minutes
        if interval < 3600 {
            return "\(Int(interval / 60))m"
        }
        // < 24 hours
        if interval < 86400 {
            return "\(Int(interval / 3600))h"
        }

        // Absolute date
        let formatter = DateFormatter()
        let isSameYear = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
        formatter.dateFormat = isSameYear ? "MMM d" : "MMM d, yyyy"
        return formatter.string(from: date)
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
