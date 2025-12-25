
import SwiftUI

/// The search bar at the top of the popover.
struct QuickFindField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 14))

            TextField("Quick Find", text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isFocused)
                // Things 3 allows typing immediately
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color.blue.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
