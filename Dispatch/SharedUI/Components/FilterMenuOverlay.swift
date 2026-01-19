//
//  FilterMenuOverlay.swift
//  Dispatch
//
//  System-native menu for filter choices.
//  - Uses a UIKit-backed UIButton + UIMenu anchored to the filter control
//  - Tracks menu show/hide to fade the control out while the menu is visible
//  - Positioned at the filter button location (bottom leading)
//

#if os(iOS)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A floating menu anchored to the filter control.
/// Uses a system-native menu anchored to the filter control, not a custom overlay.
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

  // MARK: Private

  private struct FilterButtonLiquidGlassIfAvailable: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
      if #available(iOS 26.0, *) {
        content
          .glassEffect(.regular.interactive())
      } else {
        content
      }
    }
  }

  private struct FilterMenuButton: UIViewRepresentable {
    @Binding var isPresented: Bool
    @Binding var audience: AudienceLens

    func makeCoordinator() -> Coordinator {
      Coordinator(isPresented: $isPresented, audience: $audience)
    }

    func makeUIView(context: Context) -> UIButton {
      let button = UIButton(type: .system)

      // Background approximates the system/material look without fighting the OS.
      button.backgroundColor = UIColor.secondarySystemBackground
      button.layer.cornerRadius = DS.Spacing.floatingButtonSize / 2
      button.clipsToBounds = true

      // Initial icon state.
      context.coordinator.applyIcon(to: button)

      // Provide a native menu anchored to the button.
      button.showsMenuAsPrimaryAction = true
      button.menu = context.coordinator.makeMenu()

      // Track presentation/dismissal using context menu interaction callbacks.
      let interaction = UIContextMenuInteraction(delegate: context.coordinator)
      button.addInteraction(interaction)

      // Accessibility
      button.accessibilityLabel = "Filter"

      return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {
      // Keep bindings current.
      context.coordinator.isPresented = $isPresented
      context.coordinator.audience = $audience

      // Update menu + icon when selection changes.
      uiView.menu = context.coordinator.makeMenu()
      context.coordinator.applyIcon(to: uiView)

      // Sync visual state with isPresented.
      // When menu is visible, fade the button out; when dismissed, fade it back in.
      let targetAlpha: CGFloat = isPresented ? 0.0 : 1.0
      if uiView.alpha != targetAlpha {
        if #available(iOS 26.0, *) {
          // iOS 26-native spring feel (matches the system more closely than custom SwiftUI springs here).
          UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.78,
            initialSpringVelocity: 0.7,
            options: [.allowUserInteraction, .beginFromCurrentState]
          ) {
            uiView.alpha = targetAlpha
          }
        } else {
          UIView.animate(withDuration: 0.18, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            uiView.alpha = targetAlpha
          }
        }
      }
    }

    final class Coordinator: NSObject, UIContextMenuInteractionDelegate {
      var isPresented: Binding<Bool>
      var audience: Binding<AudienceLens>

      init(isPresented: Binding<Bool>, audience: Binding<AudienceLens>) {
        self.isPresented = isPresented
        self.audience = audience
      }

      func makeMenu() -> UIMenu {
        let actions: [UIAction] = AudienceLens.allCases.map { lens in
          UIAction(
            title: lens.label,
            image: UIImage(systemName: lens.icon),
            state: lens == audience.wrappedValue ? .on : .off
          ) { _ in
            self.audience.wrappedValue = lens
            self.isPresented.wrappedValue = false
          }
        }
        return UIMenu(children: actions)
      }

      func applyIcon(to button: UIButton) {
        let image = UIImage(systemName: audience.wrappedValue.icon)
        button.setImage(image, for: .normal)
        button.tintColor = UIColor.label
        button.imageView?.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
      }

      // MARK: UIContextMenuInteractionDelegate

      func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
      ) -> UIContextMenuConfiguration? {
        UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
          self.makeMenu()
        }
      }

      func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willDisplayMenuFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
      ) {
        isPresented.wrappedValue = true
      }

      func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willEndFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
      ) {
        isPresented.wrappedValue = false
      }
    }
  }

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      FilterMenuButton(
        isPresented: $isPresented,
        audience: $audience
      )
      .frame(
        width: DS.Spacing.floatingButtonSize,
        height: DS.Spacing.floatingButtonSize
      )
      // iOS 26: opt into interactive Liquid Glass on the control itself when available.
      // This does NOT re-skin the system menu; it only affects the filter control.
      .modifier(FilterButtonLiquidGlassIfAvailable())
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    .padding(.leading, DS.Spacing.floatingButtonMargin)
    .padding(.bottom, DS.Spacing.floatingButtonBottomInset)
  }
}

// MARK: - Previews

#Preview("Filter Menu Overlay") {
  @Previewable @State var showMenu = false
  @Previewable @State var audience: AudienceLens = .all

  ZStack {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    Text("Tap the filter button")
      .font(DS.Typography.body)
      .foregroundStyle(.secondary)

    FilterMenuOverlay(
      isPresented: $showMenu,
      audience: $audience
    )
  }
}

#Preview("Filter Menu - Dark Mode") {
  @Previewable @State var showMenu = false
  @Previewable @State var audience: AudienceLens = .admin

  ZStack {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    Text("Tap the filter button")
      .font(DS.Typography.body)
      .foregroundStyle(.secondary)

    FilterMenuOverlay(
      isPresented: $showMenu,
      audience: $audience
    )
  }
  .preferredColorScheme(.dark)
}

#endif
