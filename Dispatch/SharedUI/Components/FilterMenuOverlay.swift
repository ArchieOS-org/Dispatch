//
//  FilterMenuOverlay.swift
//  Dispatch
//
//  Custom floating menu overlay for filter button with iOS 26 effects.
//  - Liquid glass material background
//  - Bounce-out spring animation
//  - Positioned over the filter button location (bottom leading)
//

#if os(iOS)
import SwiftUI

/// A floating menu overlay that appears above the filter button.
/// Uses iOS 26 liquid glass material and spring animation.
///
/// Usage:
/// ```swift
/// FilterMenuOverlay(
///   isPresented: $showMenu,
///   audience: $audience
/// )
/// ```
struct FilterMenuOverlay: View {

  // MARK: Internal

  @Binding var isPresented: Bool
  @Binding var audience: AudienceLens

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

      // Menu content - positioned at bottom leading (where filter button is)
      GeometryReader { _ in
        VStack(alignment: .leading, spacing: 0) {
          Spacer()

          if isPresented {
            menuContent
              .transition(.asymmetric(
                insertion: .scale(scale: 0.8, anchor: .bottomLeading)
                  .combined(with: .opacity),
                removal: .scale(scale: 0.9, anchor: .bottomLeading)
                  .combined(with: .opacity)
              ))
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, DS.Spacing.floatingButtonMargin)
        // Position menu above filter button: button height (56) + spacing (12) + bottom inset (24)
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
      ForEach(Array(AudienceLens.allCases.enumerated()), id: \.element) { index, lens in
        menuButton(for: lens)

        // Add separator between items (not after last)
        if index < AudienceLens.allCases.count - 1 {
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
    .frame(minWidth: 160)
  }

  @ViewBuilder
  private func menuButton(for lens: AudienceLens) -> some View {
    Button {
      // Set audience and dismiss
      audience = lens
      dismissMenu()
    } label: {
      HStack(spacing: DS.Spacing.md) {
        Image(systemName: lens.icon)
          .font(.system(size: 17, weight: .medium))
          .foregroundStyle(lens == .all ? .secondary : lens.tintColor)
          .frame(width: 24)

        Text(lens.label)
          .font(DS.Typography.body)
          .foregroundStyle(.primary)

        Spacer()

        // Checkmark for selected lens
        if lens == audience {
          Image(systemName: "checkmark")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(DS.Colors.accent)
        }
      }
      .padding(.horizontal, DS.Spacing.md)
      .padding(.vertical, DS.Spacing.sm + 2)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .sensoryFeedback(.selection, trigger: lens)
  }

  private func dismissMenu() {
    isPresented = false
  }
}

// MARK: - Previews

#Preview("Filter Menu Overlay") {
  @Previewable @State var showMenu = true
  @Previewable @State var audience: AudienceLens = .all

  ZStack {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    // Simulated filter button position
    VStack {
      Spacer()
      HStack {
        Circle()
          .fill(.ultraThinMaterial)
          .frame(width: DS.Spacing.floatingButtonSize, height: DS.Spacing.floatingButtonSize)
          .overlay {
            Image(systemName: audience.icon)
              .font(.system(size: 20, weight: .semibold))
              .foregroundStyle(audience == .all ? .primary : audience.tintColor)
          }
          .onTapGesture {
            showMenu.toggle()
          }
        Spacer()
      }
      .padding(.leading, DS.Spacing.floatingButtonMargin)
      .padding(.bottom, DS.Spacing.floatingButtonBottomInset)
    }

    FilterMenuOverlay(
      isPresented: $showMenu,
      audience: $audience
    )
  }
}

#Preview("Filter Menu - Dark Mode") {
  @Previewable @State var showMenu = true
  @Previewable @State var audience: AudienceLens = .admin

  ZStack {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    FilterMenuOverlay(
      isPresented: $showMenu,
      audience: $audience
    )
  }
  .preferredColorScheme(.dark)
}

#endif
