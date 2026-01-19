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
/// Long-press opens a confirmationDialog to select any filter directly.
struct FloatingFilterButton: View {

  // MARK: Internal

  @Binding var audience: AudienceLens

  var body: some View {
    filterButtonVisual
      .onTapGesture {
        // Tap action: cycle to next filter
        audience = audience.next
      }
      .onLongPressGesture {
        // Long-press action: show filter menu
        showFilterMenu = true
      }
      .sensoryFeedback(.selection, trigger: audience)
      .accessibilityIdentifier("AudienceFilterButton")
      .accessibilityAddTraits(.isButton)
      .accessibilityLabel("Filter: \(audience.label)")
      .accessibilityValue("\(audience.rawValue)|\(audience.icon)")
      .accessibilityHint("Tap to cycle, hold for options")
      .confirmationDialog(
        "Filter by Audience",
        isPresented: $showFilterMenu,
        titleVisibility: .hidden
      ) {
        ForEach(AudienceLens.allCases, id: \.self) { lens in
          Button {
            audience = lens
          } label: {
            Label(lens.label, systemImage: lens.icon)
          }
        }
      }
      .onChange(of: showFilterMenu) { _, isPresented in
        if isPresented {
          overlayState.hide(reason: .filterMenuOpen)
        } else {
          overlayState.show(reason: .filterMenuOpen)
        }
      }
  }

  // MARK: Private

  @EnvironmentObject private var overlayState: AppOverlayState

  /// Controls filter menu presentation (confirmationDialog)
  @State private var showFilterMenu = false

  /// Scaled icon size for Dynamic Type support (base: 20pt, relative to body)
  @ScaledMetric(relativeTo: .body)
  private var iconSize: CGFloat = 20

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
        .font(.system(size: iconSize, weight: .semibold))
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
  .environmentObject(AppOverlayState(mode: .preview))
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
  .environmentObject(AppOverlayState(mode: .preview))
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
  .environmentObject(AppOverlayState(mode: .preview))
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
  .environmentObject(AppOverlayState(mode: .preview))
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
  .environmentObject(AppOverlayState(mode: .preview))
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
  .environmentObject(AppOverlayState(mode: .preview))
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
  .environmentObject(AppOverlayState(mode: .preview))
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
  .environmentObject(AppOverlayState(mode: .preview))
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
  .environmentObject(AppOverlayState(mode: .preview))
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
  .environmentObject(AppOverlayState(mode: .preview))
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
  .environmentObject(AppOverlayState(mode: .preview))
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
  .environmentObject(AppOverlayState(mode: .preview))
}

#endif
