//
//  FABMenuOverlay.swift
//  Dispatch
//
//  Custom floating menu overlay for FAB with iOS 26 effects.
//  - Liquid glass material background
//  - Bounce-out spring animation
//  - Positioned over the FAB button location
//

import SwiftUI

// MARK: - FABMenuItem

/// Menu item for FABMenuOverlay
struct FABMenuItem: Identifiable {
  let id = UUID()
  let title: String
  let icon: String
  let action: () -> Void
}

// MARK: - FABMenuOverlay

/// A floating menu overlay that appears above the FAB button.
/// Uses iOS 26 liquid glass material and spring animation.
///
/// Usage:
/// ```swift
/// FABMenuOverlay(
///   isPresented: $showMenu,
///   items: [
///     FABMenuItem(title: "New Task", icon: "checklist", action: { ... }),
///     FABMenuItem(title: "New Activity", icon: "calendar", action: { ... })
///   ]
/// )
/// ```
struct FABMenuOverlay: View {

  // MARK: Internal

  @Binding var isPresented: Bool
  let items: [FABMenuItem]

  /// Alignment for the menu (default: bottom trailing for FAB)
  var alignment: Alignment = .bottomTrailing

  var body: some View {
    ZStack {
      // Dismiss layer - tap outside to close
      if isPresented {
        Color.black.opacity(0.001)
          .ignoresSafeArea()
          .onTapGesture {
            dismissMenu()
          }
      }

      // Menu content - positioned at bottom trailing
      GeometryReader { _ in
        VStack(alignment: .trailing, spacing: 0) {
          Spacer()

          if isPresented {
            menuContent
              .transition(.asymmetric(
                insertion: .scale(scale: 0.8, anchor: .bottomTrailing)
                  .combined(with: .opacity),
                removal: .scale(scale: 0.9, anchor: .bottomTrailing)
                  .combined(with: .opacity)
              ))
          }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, DS.Spacing.floatingButtonMargin)
        // Position menu above FAB: FAB height (56) + spacing (12) + bottom inset (24)
        .padding(.bottom, DS.Spacing.floatingButtonBottomInset + DS.Spacing.floatingButtonSizeLarge + 12)
      }
    }
    .animation(menuAnimation, value: isPresented)
  }

  // MARK: Private

  /// iOS 26 bounce-out spring animation (per Context7 docs)
  private var menuAnimation: Animation {
    .interpolatingSpring(duration: 0.35, bounce: 0.3)
  }

  @ViewBuilder
  private var menuContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
        menuButton(for: item)

        // Add separator between items (not after last)
        if index < items.count - 1 {
          Divider()
            .padding(.leading, DS.Spacing.xl) // Align with text after icon
        }
      }
    }
    .background {
      // iOS 26 liquid glass material effect
      RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium)
        .fill(.ultraThinMaterial)
    }
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium))
    .dsShadow(DS.Shadows.elevated)
    .frame(minWidth: 200)
  }

  @ViewBuilder
  private func menuButton(for item: FABMenuItem) -> some View {
    Button {
      // Dismiss first, then perform action
      dismissMenu()
      // Delay action slightly to allow dismiss animation
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        item.action()
      }
    } label: {
      HStack(spacing: DS.Spacing.md) {
        Image(systemName: item.icon)
          .font(.system(size: 17, weight: .medium))
          .foregroundStyle(.secondary)
          .frame(width: 24)

        Text(item.title)
          .font(DS.Typography.body)
          .foregroundStyle(.primary)

        Spacer()
      }
      .padding(.horizontal, DS.Spacing.md)
      .padding(.vertical, DS.Spacing.sm + 2)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    #if os(iOS)
      .sensoryFeedback(.selection, trigger: item.id)
    #endif
  }

  private func dismissMenu() {
    isPresented = false
  }
}

// MARK: - Previews

#Preview("FAB Menu Overlay") {
  @Previewable @State var showMenu = true

  ZStack {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    // Simulated FAB button position
    VStack {
      Spacer()
      HStack {
        Spacer()
        Circle()
          .fill(DS.Colors.accent)
          .frame(width: DS.Spacing.floatingButtonSizeLarge, height: DS.Spacing.floatingButtonSizeLarge)
          .overlay {
            Image(systemName: "plus")
              .font(.system(size: 24, weight: .semibold))
              .foregroundColor(.white)
          }
          .onTapGesture {
            showMenu.toggle()
          }
      }
      .padding(.trailing, DS.Spacing.floatingButtonMargin)
      .padding(.bottom, DS.Spacing.floatingButtonBottomInset)
    }

    FABMenuOverlay(
      isPresented: $showMenu,
      items: [
        FABMenuItem(title: "New Task", icon: DS.Icons.Entity.task) { },
        FABMenuItem(title: "New Activity", icon: DS.Icons.Entity.activity) { },
        FABMenuItem(title: "New Listing", icon: DS.Icons.Entity.listing) { }
      ]
    )
  }
}

#Preview("FAB Menu - Two Items") {
  @Previewable @State var showMenu = true

  ZStack {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    FABMenuOverlay(
      isPresented: $showMenu,
      items: [
        FABMenuItem(title: "New Property", icon: DS.Icons.Entity.property) { },
        FABMenuItem(title: "New Listing", icon: DS.Icons.Entity.listing) { }
      ]
    )
  }
}

#Preview("FAB Menu - Dark Mode") {
  @Previewable @State var showMenu = true

  ZStack {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    FABMenuOverlay(
      isPresented: $showMenu,
      items: [
        FABMenuItem(title: "New Task", icon: DS.Icons.Entity.task) { },
        FABMenuItem(title: "New Activity", icon: DS.Icons.Entity.activity) { },
        FABMenuItem(title: "New Listing", icon: DS.Icons.Entity.listing) { }
      ]
    )
  }
  .preferredColorScheme(.dark)
}
