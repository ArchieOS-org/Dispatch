//
//  NotesSection.swift
//  Dispatch
//
//  Unified Notes Component
//  Jobs-Standard: Single file, minimal API, no configuration flags
//

import SwiftUI

// MARK: - Public API

/// Styled notes section with header, background, composer, and note list.
/// Jobs-standard: no configuration flags, one canonical appearance.
struct NotesSection: View {
  let notes: [Note]
  let userLookup: (UUID) -> User?
  let onSave: (String) -> Void
  var onDelete: ((Note) -> Void)? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      Text("Notes")
        .font(DS.Typography.headline)
        .foregroundColor(DS.Colors.Text.primary)

      NotesContent(
        notes: notes,
        userLookup: userLookup,
        onSave: onSave,
        onDelete: onDelete
      )
    }
    .padding(DS.Spacing.md)
    .background(DS.Colors.Background.card)
    .cornerRadius(DS.Spacing.radiusCard)
  }
}

/// Unstyled notes content for custom containers.
/// Same API, no header/background/padding.
struct NotesContent: View {
  let notes: [Note]
  let userLookup: (UUID) -> User?
  let onSave: (String) -> Void
  var onDelete: ((Note) -> Void)? = nil

  @State private var noteText = ""
  @FocusState private var isComposerFocused: Bool

  private var visibleNotes: [Note] {
    notes
      .filter { $0.deletedAt == nil }
      .sorted { $0.createdAt < $1.createdAt }
  }

  var body: some View {
    ZStack {
      // Tap anywhere in the notes area to dismiss the editor focus
      Color.clear
        .contentShape(Rectangle())
        .onTapGesture {
          isComposerFocused = false
        }

      VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        // Note list
        if !visibleNotes.isEmpty {
          LazyVStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(visibleNotes) { note in
              NoteCard(
                note: note,
                author: userLookup(note.createdBy),
                onDelete: onDelete.map { callback in { callback(note) } },
                onTap: {
                  isComposerFocused = false
                }
              )
            }
          }
          .accessibilityElement(children: .contain)
          .accessibilityLabel("Notes list with \(visibleNotes.count) note\(visibleNotes.count == 1 ? "" : "s")")
        }

        if !visibleNotes.isEmpty {
          Divider()
            .padding(.vertical, DS.Spacing.xs)
        }

        // Composer (always visible)
        NoteComposer(text: $noteText, isFocused: $isComposerFocused, onSave: onSave)
      }
    }
  }
}

// MARK: - Private Subviews

/// Single note display card with author, content, and optional context menu delete.
private struct NoteCard: View {
  let note: Note
  let author: User?
  var onDelete: (() -> Void)?
  var onTap: (() -> Void)? = nil

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
    .contentShape(Rectangle())
    .onTapGesture {
      onTap?()
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Note by \(author?.name ?? "Unknown"): \(note.content)")
    .contextMenu {
      if let onDelete = onDelete {
        Button(role: .destructive, action: onDelete) {
          Label("Delete", systemImage: "trash")
        }
      }
    }
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

/// Always-visible inline composer for creating notes.
/// - Placeholder: "Add a note…"
/// - Commit on blur (focus lost) or tap send icon
/// - Double-commit protection via isCommitting guard
private struct NoteComposer: View {
  @Binding var text: String
  @FocusState.Binding var isFocused: Bool
  var onSave: (String) -> Void

  @State private var isCommitting = false

  private var hasValidInput: Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    HStack(alignment: .top, spacing: DS.Spacing.sm) {
      ZStack(alignment: .topLeading) {
        // Placeholder (visible when empty and not focused)
        if text.isEmpty && !isFocused {
          Text("Add a note…")
            .font(DS.Typography.body)
            .foregroundColor(DS.Colors.Text.tertiary)
            .padding(.vertical, DS.Spacing.xs)
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
    .padding(.vertical, DS.Spacing.xs)
    .cornerRadius(DS.Spacing.radiusCard)
    .animation(.easeInOut(duration: 0.15), value: isFocused)
    .animation(.easeInOut(duration: 0.15), value: hasValidInput)
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

// MARK: - Previews

private let previewNotes: [Note] = (0..<3).map { i in
  Note(
    content: "Note \(i + 1): This is sample content for testing.",
    createdBy: UUID(),
    parentType: .task,
    parentId: UUID()
  )
}

#Preview("Notes Section - With Notes") {
  ScrollView {
    NotesSection(
      notes: previewNotes,
      userLookup: { _ in User(name: "Test User", email: "test@example.com", userType: .admin) },
      onSave: { print("Saved: \($0)") },
      onDelete: { print("Delete: \($0.id)") }
    )
    .padding()
  }
}

#Preview("Notes Section - Empty") {
  NotesSection(
    notes: [],
    userLookup: { _ in nil },
    onSave: { print("Saved: \($0)") }
  )
  .padding()
}

#Preview("Notes Content - Unstyled") {
  VStack {
    Text("Custom Container")
      .font(.headline)
    NotesContent(
      notes: previewNotes.prefix(2).map { $0 },
      userLookup: { _ in User(name: "Jane Doe", email: "jane@example.com", userType: .marketing) },
      onSave: { print("Saved: \($0)") },
      onDelete: { print("Delete: \($0.id)") }
    )
  }
  .padding()
}
