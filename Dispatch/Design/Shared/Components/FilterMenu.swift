//
//  FilterMenu.swift
//  Dispatch
//
//  Toolbar filter icon button for iPad and macOS.
//  - Tap/click to cycle through filters (All → Admin → Marketing → All)
//  - Long-press (iPad) or right-click (macOS) opens menu with all options
//  - Icon-only design matches ToolbarIconButton sizing
//

import SwiftUI

/// A toolbar filter button for iPad and macOS that matches ToolbarIconButton sizing.
/// Split control pattern: left segment cycles, right chevron opens menu.
/// - Tap icon: Cycles through audience filters (All → Admin → Marketing → All)
/// - Tap chevron: Opens menu with all filter options and checkmark on current
struct FilterMenu: View {

  // MARK: Internal

  @Binding var audience: AudienceLens

  var body: some View {
    HStack(spacing: 0) {
      // Left: Filter icon button (tap to cycle)
      Button {
        audience = audience.next
      } label: {
        Image(systemName: audience.icon)
          .symbolRenderingMode(.monochrome)
          .font(.system(size: toolbarIconSize, weight: .medium))
          .foregroundStyle(iconColor)
          .frame(
            width: DS.Spacing.bottomToolbarButtonSize,
            height: DS.Spacing.bottomToolbarButtonSize
          )
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      #if os(macOS)
        .help("Filter")
      #endif
        .accessibilityIdentifier("AudienceFilterButton")
        .accessibilityLabel("Cycle filter")
        .accessibilityValue("\(audience.rawValue)|\(audience.icon)")

      // Right: Chevron menu trigger with Picker
      Menu {
        Picker("Filter", selection: $audience) {
          ForEach(AudienceLens.allCases, id: \.self) { lens in
            Text(lens.label)
              .tag(lens)
          }
        }
        .pickerStyle(.inline)
        .labelsHidden()
      } label: {
        Image(systemName: "chevron.down")
          .font(.system(size: chevronSize, weight: .bold))
          .foregroundStyle(.secondary)
          .frame(width: 44, height: DS.Spacing.bottomToolbarButtonSize)
          .contentShape(Rectangle())
      }
      // NOTE: .menuStyle(.borderlessButton) is deprecated and creates pill-shaped background.
      // Use .menuStyle(.button) + .buttonStyle(.plain) for minimal chrome.
      .menuStyle(.button)
      .buttonStyle(.plain)
      .menuIndicator(.hidden)
      .tint(.secondary)
      #if os(macOS)
        .help("Choose filter")
      #endif
        .accessibilityLabel("Choose filter")
        .accessibilityValue(audience.label)
    }
    .sensoryFeedback(.selection, trigger: audience)
  }

  // MARK: Private

  /// Scaled icon size for Dynamic Type support (base: 17pt, relative to headline)
  @ScaledMetric(relativeTo: .headline)
  private var toolbarIconSize: CGFloat = 17

  @ScaledMetric(relativeTo: .caption2)
  private var chevronSize: CGFloat = 10

  /// Icon color: uses tint color for active filters, standard toolbar color otherwise
  private var iconColor: Color {
    switch audience {
    case .all:
      .primary.opacity(0.6)
    case .admin:
      DS.Colors.RoleColors.admin
    case .marketing:
      DS.Colors.RoleColors.marketing
    }
  }
}

// MARK: - Previews

// MARK: Interactive

/// Interactive preview - tap to cycle, hold for menu
#Preview("Interactive") {
  @Previewable @State var audience: AudienceLens = .all

  VStack(spacing: DS.Spacing.lg) {
    Text("Current: \(audience.label)")
      .font(DS.Typography.headline)
      .foregroundStyle(.secondary)

    FilterMenu(audience: $audience)

    Text("Tap to cycle • Hold for menu")
      .font(DS.Typography.caption)
      .foregroundStyle(.tertiary)
  }
  .padding(DS.Spacing.xl)
}

// MARK: All States Gallery

/// Shows all filter states side by side
#Preview("All States Gallery") {
  HStack(spacing: DS.Spacing.md) {
    ForEach(AudienceLens.allCases, id: \.self) { lens in
      VStack(spacing: DS.Spacing.xs) {
        FilterMenu(audience: .constant(lens))
        Text(lens.label)
          .font(DS.Typography.captionSecondary)
          .foregroundStyle(.tertiary)
      }
    }
  }
  .padding(DS.Spacing.xl)
}

// MARK: Size Comparison

/// Shows FilterMenu next to ToolbarIconButton for size comparison
#Preview("Size Comparison with Toolbar Icons") {
  @Previewable @State var audience: AudienceLens = .admin

  HStack(spacing: 0) {
    FilterMenu(audience: $audience)

    // Simulated toolbar icon buttons (same frame size)
    ForEach(["plus", "magnifyingglass", "trash"], id: \.self) { icon in
      Image(systemName: icon)
        .font(.system(size: DS.Spacing.bottomToolbarIconSize, weight: .medium))
        .foregroundStyle(.primary.opacity(0.6))
        .frame(
          width: DS.Spacing.bottomToolbarButtonSize,
          height: DS.Spacing.bottomToolbarButtonSize
        )
    }
  }
  .padding(DS.Spacing.xl)
  .background(DS.Colors.Background.secondary)
}

// MARK: Color Schemes

/// Light mode
#Preview("Light Mode") {
  HStack(spacing: DS.Spacing.md) {
    ForEach(AudienceLens.allCases, id: \.self) { lens in
      FilterMenu(audience: .constant(lens))
    }
  }
  .padding(DS.Spacing.xl)
  .preferredColorScheme(.light)
}

/// Dark mode
#Preview("Dark Mode") {
  HStack(spacing: DS.Spacing.md) {
    ForEach(AudienceLens.allCases, id: \.self) { lens in
      FilterMenu(audience: .constant(lens))
    }
  }
  .padding(DS.Spacing.xl)
  .preferredColorScheme(.dark)
}

// MARK: In Toolbar Context

/// Shows filter in a simulated bottom toolbar
#Preview("In Toolbar Context") {
  @Previewable @State var audience: AudienceLens = .marketing

  VStack(spacing: 0) {
    DS.Colors.Background.secondary
      .frame(height: 200)

    HStack(spacing: 0) {
      FilterMenu(audience: $audience)

      Image(systemName: "plus")
        .font(.system(size: DS.Spacing.bottomToolbarIconSize, weight: .medium))
        .foregroundStyle(.primary.opacity(0.6))
        .frame(
          width: DS.Spacing.bottomToolbarButtonSize,
          height: DS.Spacing.bottomToolbarButtonSize
        )

      Spacer()

      Image(systemName: "magnifyingglass")
        .font(.system(size: DS.Spacing.bottomToolbarIconSize, weight: .medium))
        .foregroundStyle(.primary.opacity(0.6))
        .frame(
          width: DS.Spacing.bottomToolbarButtonSize,
          height: DS.Spacing.bottomToolbarButtonSize
        )
    }
    .padding(.horizontal, DS.Spacing.bottomToolbarPadding)
    .frame(height: DS.Spacing.bottomToolbarHeight)
    .background(.regularMaterial)
  }
  .frame(width: 400)
}
