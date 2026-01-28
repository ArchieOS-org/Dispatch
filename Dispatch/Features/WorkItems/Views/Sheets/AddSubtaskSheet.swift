//
//  AddSubtaskSheet.swift
//  Dispatch
//
//  Sheet for adding a new subtask
//  Created by Claude on 2025-12-06.
//

import SwiftUI

/// Simple sheet for entering a new subtask title.
/// Used from detail views when tapping "Add Subtask".
struct AddSubtaskSheet: View {

  // MARK: Internal

  @Binding var title: String

  var onSave: () -> Void

  var body: some View {
    NavigationStack {
      StandardScreen(
        title: "Add Subtask",
        layout: .column,
        scroll: .disabled
      ) {
        Form {
          Section {
            TextField("Subtask title", text: $title)
          } header: {
            Text("New Subtask")
          }
        }
        .formStyle(.grouped)
      } toolbarContent: {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            title = ""
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") {
            title = title.trimmingCharacters(in: .whitespaces)
            onSave()
          }
          .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
    }
    #if os(iOS)
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    #endif
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss

}

// MARK: - Preview

#Preview("Add Subtask Sheet") {
  @Previewable @State var title = ""

  AddSubtaskSheet(title: $title) { }
}
