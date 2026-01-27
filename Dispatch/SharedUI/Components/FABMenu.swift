//
//  FABMenu.swift
//  Dispatch
//
//  Floating action button menu that springs out with options for creating
//  Listings, Tasks, and Activities. Replaces the single FAB when expanded.
//
//  iOS 26 Glass Styling:
//  - iOS 26+: Uses native `glassCapsuleBackground()` for Liquid Glass
//  - Pre-iOS 26: Falls back to `.regularMaterial` capsule backgrounds
//
//  Glass styling is handled by the DesignSystem's GlassEffect modifiers,
//  which automatically apply native glass on iOS 26+ with material fallback.
//

import DesignSystem
import SwiftUI

// MARK: - FABMenuOption

/// Options available in the FAB menu
enum FABMenuOption: CaseIterable, Identifiable {
  case listing
  case task
  case activity

  // MARK: Internal

  var id: String { rawValue }

  var rawValue: String {
    switch self {
    case .listing: "listing"
    case .task: "task"
    case .activity: "activity"
    }
  }

  var displayName: String {
    switch self {
    case .listing: "Listing"
    case .task: "Task"
    case .activity: "Activity"
    }
  }

  var icon: String {
    switch self {
    case .listing: DS.Icons.Entity.listing
    case .task: DS.Icons.Entity.task
    case .activity: DS.Icons.Entity.activity
    }
  }

  var accessibilityLabel: String {
    "Create new \(displayName.lowercased())"
  }
}

// MARK: - FABMenu

/// Floating action button with an expandable menu for creating different item types.
/// When tapped, the FAB transforms into a menu with Listing, Task, and Activity options.
/// Tapping outside the menu or selecting an option dismisses the menu.
struct FABMenu: View {

  // MARK: Internal

  /// Callback when a menu option is selected
  let onSelect: (FABMenuOption) -> Void

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      // Scrim layer - tap to dismiss
      if isExpanded {
        Color.black.opacity(0.001) // Near-transparent but still tappable
          .ignoresSafeArea()
          .contentShape(Rectangle())
          .onTapGesture {
            dismissMenu()
          }
          .accessibilityLabel("Dismiss menu")
          .accessibilityAddTraits(.isButton)
      }

      // Menu content
      VStack(alignment: .trailing, spacing: DS.Spacing.sm) {
        // Menu options (shown when expanded)
        if isExpanded {
          ForEach(Array(FABMenuOption.allCases.enumerated()), id: \.element.id) { index, option in
            FABMenuButton(option: option) {
              selectOption(option)
            }
            .transition(
              .asymmetric(
                insertion: .scale(scale: 0.5).combined(with: .opacity),
                removal: .scale(scale: 0.8).combined(with: .opacity)
              )
            )
            .animation(
              .spring(response: 0.35, dampingFraction: 0.7)
                .delay(Double(FABMenuOption.allCases.count - 1 - index) * 0.05),
              value: isExpanded
            )
          }
        }

        // Main FAB button
        FloatingActionButton(
          action: { toggleMenu() },
          icon: isExpanded ? "xmark" : "plus",
          accessibilityLabelText: isExpanded ? "Close menu" : "Open creation menu"
        )
        .rotationEffect(.degrees(isExpanded ? 45 : 0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
      }
    }
  }

  // MARK: Private

  @State private var isExpanded = false

  /// Haptic trigger for menu state changes
  @State private var hapticTrigger = 0

  private func toggleMenu() {
    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
      isExpanded.toggle()
    }
    hapticTrigger += 1
  }

  private func dismissMenu() {
    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
      isExpanded = false
    }
  }

  private func selectOption(_ option: FABMenuOption) {
    // Dismiss menu first, then trigger callback
    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
      isExpanded = false
    }
    // Small delay to let animation start before triggering sheet
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      onSelect(option)
    }
  }
}

// MARK: - FABMenuButton

/// Individual menu button for FAB menu options
///
/// iOS 26 Glass Styling:
/// - iOS 26+: Uses native Liquid Glass background via `glassCapsuleBackground()`
/// - Pre-iOS 26: Falls back to `.regularMaterial` capsule background
private struct FABMenuButton: View {

  // MARK: Internal

  let option: FABMenuOption
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: DS.Spacing.sm) {
        Text(option.displayName)
          .font(DS.Typography.callout)
          .fontWeight(.medium)
          .foregroundColor(DS.Colors.Text.primary)

        Image(systemName: option.icon)
          .font(.system(size: scaledIconSize, weight: .semibold))
          .foregroundColor(.white)
          .frame(width: buttonSize, height: buttonSize)
          .background(DS.Colors.accent)
          .clipShape(Circle())
      }
      .padding(.leading, DS.Spacing.md)
      .padding(.trailing, DS.Spacing.xs)
      .padding(.vertical, DS.Spacing.xs)
      // iOS 26+: Native Liquid Glass via glassCapsuleBackground()
      // Pre-iOS 26: Falls back to regularMaterial capsule
      .glassCapsuleBackground()
    }
    .buttonStyle(.plain)
    #if os(iOS)
      .sensoryFeedback(.impact(flexibility: .soft), trigger: hapticTrigger)
    #endif
      .accessibilityLabel(option.accessibilityLabel)
  }

  // MARK: Private

  /// Button size for menu items (slightly smaller than main FAB)
  private let buttonSize: CGFloat = 44

  /// Scaled icon size for Dynamic Type support
  @ScaledMetric(relativeTo: .body)
  private var scaledIconSize: CGFloat = 18

  /// Haptic trigger
  @State private var hapticTrigger = 0
}

// MARK: - Previews

#if DEBUG
#Preview("FAB Menu - Collapsed") {
  ZStack(alignment: .bottomTrailing) {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    FABMenu { option in
      // swiftlint:disable:next no_direct_standard_out_logs
      print("Selected: \(option.displayName)")
    }
    .padding(.trailing, DS.Spacing.floatingButtonMargin)
    .padding(.bottom, DS.Spacing.floatingButtonBottomInset)
  }
}

#Preview("FAB Menu - Expanded") {
  ZStack(alignment: .bottomTrailing) {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    // Simulated expanded state for preview
    VStack(alignment: .trailing, spacing: DS.Spacing.sm) {
      ForEach(FABMenuOption.allCases) { option in
        FABMenuButton(option: option) { }
      }

      FloatingActionButton(action: { }, icon: "xmark")
        .rotationEffect(.degrees(45))
    }
    .padding(.trailing, DS.Spacing.floatingButtonMargin)
    .padding(.bottom, DS.Spacing.floatingButtonBottomInset)
  }
}
#endif
