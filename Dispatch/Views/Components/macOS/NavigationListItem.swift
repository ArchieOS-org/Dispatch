
import SwiftUI

/// Each row in the navigation popover (icon, label, badge, selection state).
struct NavigationListItem: View {
    let title: String
    let icon: String
    let badgeCount: Int?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Checkmark selection indicator
                // Things 3 uses a blue highlight background, but for now we follow the user's checklist
                // "Selection indicator: Blue highlight + checkmark"
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 20, alignment: .center)

                // Title
                Text(title)
                    .font(.body)
                    .foregroundColor(isSelected ? .white : .primary)

                Spacer()

                // Checkmark (if selected)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }

                // Badge (if exists and not selected - selected usually hides or inverts)
                if let count = badgeCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.blue : (isHovering ? Color.secondary.opacity(0.1) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
