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
    .accessibilityIdentifier("AudienceFilterButton")
    .accessibilityLabel("Filter: \(audience.label)")
    .accessibilityValue("\(audience.rawValue)|\(audience.icon)")
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
        .dsShadow(DS.Shadows.medium)

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

// MARK: - Previews

// MARK: Interactive

/// Interactive preview - tap to cycle through filters, hold for menu
#Preview("Interactive") {
  @Previewable @State var audience: AudienceLens = .all

  ZStack {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    VStack(spacing: DS.Spacing.lg) {
      Text("Current: \(audience.label)")
        .font(DS.Typography.headline)
        .foregroundStyle(.secondary)

      FloatingFilterButton(audience: $audience)

      Text("Tap to cycle • Hold for menu")
        .font(DS.Typography.caption)
        .foregroundStyle(.tertiary)
    }
  }
}

// MARK: All States Gallery

/// Shows all filter states side by side for comparison
#Preview("All States Gallery") {
  ZStack {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    VStack(spacing: DS.Spacing.xl) {
      Text("Filter States")
        .font(DS.Typography.headline)
        .foregroundStyle(.secondary)

      HStack(spacing: DS.Spacing.xl) {
        ForEach(AudienceLens.allCases, id: \.self) { lens in
          VStack(spacing: DS.Spacing.sm) {
            FloatingFilterButton(audience: .constant(lens))
            Text(lens.label)
              .font(DS.Typography.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }
}

// MARK: Dark Mode

/// Light mode appearance
#Preview("Light Mode") {
  ZStack {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    HStack(spacing: DS.Spacing.xl) {
      ForEach(AudienceLens.allCases, id: \.self) { lens in
        FloatingFilterButton(audience: .constant(lens))
      }
    }
  }
  .preferredColorScheme(.light)
}

/// Dark mode appearance - verifies glass material and colors
#Preview("Dark Mode") {
  ZStack {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    HStack(spacing: DS.Spacing.xl) {
      ForEach(AudienceLens.allCases, id: \.self) { lens in
        FloatingFilterButton(audience: .constant(lens))
      }
    }
  }
  .preferredColorScheme(.dark)
}

// MARK: Background Contexts

/// Tests glass effect on image background
#Preview("On Image Background") {
  ZStack {
    LinearGradient(
      colors: [.blue, .purple, .pink],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .ignoresSafeArea()

    HStack(spacing: DS.Spacing.xl) {
      ForEach(AudienceLens.allCases, id: \.self) { lens in
        FloatingFilterButton(audience: .constant(lens))
      }
    }
  }
}

/// Tests glass effect on dark content
#Preview("On Dark Content") {
  ZStack {
    Color.black
      .ignoresSafeArea()

    HStack(spacing: DS.Spacing.xl) {
      ForEach(AudienceLens.allCases, id: \.self) { lens in
        FloatingFilterButton(audience: .constant(lens))
      }
    }
  }
}

/// Tests glass effect on light content
#Preview("On Light Content") {
  ZStack {
    Color.white
      .ignoresSafeArea()

    HStack(spacing: DS.Spacing.xl) {
      ForEach(AudienceLens.allCases, id: \.self) { lens in
        FloatingFilterButton(audience: .constant(lens))
      }
    }
  }
}

// MARK: Positioned Context

/// Shows button in typical bottom-right floating position
#Preview("Bottom Right Position") {
  @Previewable @State var audience: AudienceLens = .all

  ZStack(alignment: .bottomTrailing) {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    // Simulated list content
    ScrollView {
      LazyVStack(spacing: DS.Spacing.md) {
        ForEach(0 ..< 20, id: \.self) { index in
          RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium)
            .fill(DS.Colors.Background.primary)
            .frame(height: 60)
            .overlay(
              Text("Item \(index + 1)")
                .foregroundStyle(.secondary)
            )
        }
      }
      .padding()
    }

    FloatingFilterButton(audience: $audience)
      .padding(.trailing, DS.Spacing.floatingButtonBottomInset)
      .padding(.bottom, DS.Spacing.floatingButtonBottomInset)
  }
}

// MARK: Size Reference

/// Shows the 56pt hit area vs 44pt visual circle
#Preview("Hit Area vs Visual") {
  ZStack {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    VStack(spacing: DS.Spacing.xl) {
      Text("Hit Area (56pt) vs Visual (44pt)")
        .font(DS.Typography.caption)
        .foregroundStyle(.secondary)

      ZStack {
        // 56pt hit area indicator
        Circle()
          .stroke(Color.red.opacity(0.5), lineWidth: 2)
          .frame(width: DS.Spacing.floatingButtonSizeLarge, height: DS.Spacing.floatingButtonSizeLarge)

        // 44pt visual indicator
        Circle()
          .stroke(Color.blue.opacity(0.5), lineWidth: 2)
          .frame(width: DS.Spacing.floatingButtonSize, height: DS.Spacing.floatingButtonSize)

        FloatingFilterButton(audience: .constant(.all))
      }

      HStack(spacing: DS.Spacing.md) {
        Circle()
          .fill(Color.red.opacity(0.5))
          .frame(width: 12, height: 12)
        Text("56pt tap target")
          .font(DS.Typography.captionSecondary)

        Circle()
          .fill(Color.blue.opacity(0.5))
          .frame(width: 12, height: 12)
        Text("44pt visual")
          .font(DS.Typography.captionSecondary)
      }
      .foregroundStyle(.secondary)
    }
  }
}

// MARK: Accessibility

/// Large Dynamic Type preview
#Preview("Large Dynamic Type") {
  ZStack {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    VStack(spacing: DS.Spacing.xl) {
      Text("Accessibility Test")
        .font(DS.Typography.headline)

      HStack(spacing: DS.Spacing.xl) {
        ForEach(AudienceLens.allCases, id: \.self) { lens in
          VStack(spacing: DS.Spacing.sm) {
            FloatingFilterButton(audience: .constant(lens))
            Text(lens.label)
              .font(DS.Typography.caption)
          }
        }
      }
    }
  }
  .environment(\.dynamicTypeSize, .accessibility3)
}

/// Bold text preview - tests icon weight visibility
#Preview("Bold Text") {
  ZStack {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    VStack(spacing: DS.Spacing.xl) {
      Text("Bold Text: ON")
        .font(DS.Typography.caption)
        .foregroundStyle(.secondary)

      HStack(spacing: DS.Spacing.xl) {
        ForEach(AudienceLens.allCases, id: \.self) { lens in
          FloatingFilterButton(audience: .constant(lens))
        }
      }
    }
  }
  .environment(\.legibilityWeight, .bold)
}

// MARK: With FAB Companion

/// Shows filter button alongside the primary FAB
#Preview("With FAB") {
  @Previewable @State var audience: AudienceLens = .admin

  ZStack(alignment: .bottom) {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    HStack(alignment: .bottom, spacing: DS.Spacing.md) {
      Spacer()

      FloatingFilterButton(audience: $audience)

      FloatingActionButton { }
    }
    .padding(.horizontal, DS.Spacing.floatingButtonBottomInset)
    .padding(.bottom, DS.Spacing.floatingButtonBottomInset)
  }
}

#endif
