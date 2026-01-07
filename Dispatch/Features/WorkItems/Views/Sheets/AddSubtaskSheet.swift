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
    @Binding var title: String
    var onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Subtask title", text: $title)
                } header: {
                    Text("New Subtask")
                }
            }
            .navigationTitle("Add Subtask")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
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
        .presentationDetents([.medium])
        #endif
    }
}

// MARK: - Preview

#Preview("Add Subtask Sheet") {
    @Previewable @State var title = ""

    AddSubtaskSheet(title: $title) {
        print("Saving subtask: \(title)")
    }
}
