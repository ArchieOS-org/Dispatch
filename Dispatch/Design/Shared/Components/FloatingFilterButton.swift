//
//  FloatingFilterButton.swift
//  Dispatch
//
//  Floating glass filter button for iPhone.
//  - 56pt tappable area (matches FAB)
//  - 44pt visual glass circle
//  - Tap to cycle filters
//  - Long-press (hold) for filter menu
//

#if os(iOS)
import SwiftUI

/// A floating filter button for iPhone with glass background and haptic feedback.
/// Tap cycles through audience filters (All → Admin → Marketing → All).
/// Long-press opens a menu to select any filter directly.
struct FloatingFilterButton: View {

  // MARK: Internal

  @Binding var audience: AudienceLens

  var body: some View {
    Menu {
      // Long-press menu content
      Picker(selection: $audience) {
        ForEach(AudienceLens.allCases, id: \.self) { lens in
          Label(lens.label, systemImage: lens.icon)
            .tag(lens)
        }
      } label: {
        EmptyView()
      }
    } label: {
      filterButtonVisual
    } primaryAction: {
      // Tap action: cycle to next filter
      audience = audience.next
    }
    .menuIndicator(.hidden)
    .sensoryFeedback(.selection, trigger: audience)
    .accessibilityLabel("Filter: \(audience.label)")
    .accessibilityHint("Tap to cycle, hold for options")
  }

  // MARK: Private

  @ViewBuilder
  private var filterButtonVisual: some View {
    ZStack {
      // 44pt glass circle, centered in 56pt hit area
      Circle()
        .fill(.ultraThinMaterial)
        .frame(width: DS.Spacing.floatingButtonSize, height: DS.Spacing.floatingButtonSize)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

      // Icon
      Image(systemName: audience.icon)
        .symbolRenderingMode(.monochrome)
        .foregroundStyle(audience == .all ? .primary : audience.tintColor)
        .font(.system(size: DS.Spacing.floatingButtonIconSize, weight: .semibold))
    }
    .frame(width: DS.Spacing.floatingButtonSizeLarge, height: DS.Spacing.floatingButtonSizeLarge)
    .contentShape(Circle())
  }
}

// MARK: - Preview

#Preview("FloatingFilterButton - All") {
  ZStack {
    Color.gray.opacity(0.2).ignoresSafeArea()
    FloatingFilterButton(audience: .constant(.all))
  }
}

#Preview("FloatingFilterButton - Admin") {
  ZStack {
    Color.gray.opacity(0.2).ignoresSafeArea()
    FloatingFilterButton(audience: .constant(.admin))
  }
}

#Preview("FloatingFilterButton - Marketing") {
  ZStack {
    Color.gray.opacity(0.2).ignoresSafeArea()
    FloatingFilterButton(audience: .constant(.marketing))
  }
}
#endif
