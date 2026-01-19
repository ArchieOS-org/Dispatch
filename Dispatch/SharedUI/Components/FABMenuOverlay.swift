//
//  FABMenuOverlay.swift
//  Dispatch
//
//  System-native menu for FAB choices.
//  - Uses system-native Menu anchored to the FAB button
//  - Simplified UI with native styling and behavior
//  - Positioned over the FAB button location
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
/// Uses system-native Menu anchored to the FAB.
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

  private struct FABLiquidGlassIfAvailable: ViewModifier {
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

  #if os(iOS)
  private struct FABMenuButton: UIViewRepresentable {
    @Binding var isPresented: Bool
    let items: [FABMenuItem]

    func makeCoordinator() -> Coordinator {
      Coordinator(isPresented: $isPresented, items: items)
    }

    func makeUIView(context: Context) -> UIButton {
      let button = UIButton(type: .system)
      button.backgroundColor = UIColor(DS.Colors.accent)
      button.layer.cornerRadius = DS.Spacing.floatingButtonSizeLarge / 2
      button.clipsToBounds = true

      let image = UIImage(systemName: "plus")
      button.setImage(image, for: .normal)
      button.tintColor = .white
      button.imageView?.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)

      // Provide a native menu anchored to the button.
      button.showsMenuAsPrimaryAction = true
      button.menu = context.coordinator.makeMenu()

      // Track presentation/dismissal using the underlying context menu interaction.
      let interaction = UIContextMenuInteraction(delegate: context.coordinator)
      button.addInteraction(interaction)

      // Accessibility
      button.accessibilityLabel = "Create"

      return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {
      // Keep the menu up to date if items change.
      context.coordinator.items = items
      uiView.menu = context.coordinator.makeMenu()

      // Sync visual state with isPresented.
      // When menu is visible, fade the button out; when dismissed, fade it back in.
      let targetAlpha: CGFloat = isPresented ? 0.0 : 1.0
      if uiView.alpha != targetAlpha {
        if #available(iOS 26.0, *) {
          // iOS 26-native spring feel.
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
      var items: [FABMenuItem]

      init(isPresented: Binding<Bool>, items: [FABMenuItem]) {
        self.isPresented = isPresented
        self.items = items
      }

      func makeMenu() -> UIMenu {
        let actions: [UIAction] = items.map { item in
          UIAction(title: item.title, image: UIImage(systemName: item.icon)) { _ in
            self.isPresented.wrappedValue = false
            item.action()
          }
        }
        return UIMenu(children: actions)
      }

      // MARK: UIContextMenuInteractionDelegate

      func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
      ) -> UIContextMenuConfiguration? {
        // Returning a configuration enables the interaction callbacks.
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
  #endif

  var body: some View {
    ZStack(alignment: alignment) {
      #if os(iOS)
      FABMenuButton(
        isPresented: $isPresented,
        items: items
      )
      .frame(
        width: DS.Spacing.floatingButtonSizeLarge,
        height: DS.Spacing.floatingButtonSizeLarge
      )
      // iOS 26: opt into interactive Liquid Glass on the control itself when available.
      .modifier(FABLiquidGlassIfAvailable())
      #else
      Menu {
        ForEach(items) { item in
          Button {
            isPresented = false
            item.action()
          } label: {
            Label(item.title, systemImage: item.icon)
          }
        }
      } label: {
        Circle()
          .fill(DS.Colors.accent)
          .frame(
            width: DS.Spacing.floatingButtonSizeLarge,
            height: DS.Spacing.floatingButtonSizeLarge
          )
          .overlay {
            Image(systemName: "plus")
              .font(.system(size: 24, weight: .semibold))
              .foregroundColor(.white)
          }
          .accessibilityLabel("Create")
      }
      .buttonStyle(.plain)
      .modifier(FABLiquidGlassIfAvailable())
      #endif
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    .padding(.trailing, DS.Spacing.floatingButtonMargin)
    .padding(.bottom, DS.Spacing.floatingButtonBottomInset)
  }
}

// MARK: - Previews

#Preview("FAB Menu Overlay") {
  @Previewable @State var showMenu = false

  ZStack {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    Text("Tap the + button")
      .font(DS.Typography.body)
      .foregroundStyle(.secondary)

    FABMenuOverlay(
      isPresented: $showMenu,
      items: [
        FABMenuItem(title: "New Task", icon: DS.Icons.Entity.task) { },
        FABMenuItem(title: "New Activity", icon: DS.Icons.Entity.activity) { },
        FABMenuItem(title: "New Listing", icon: DS.Icons.Entity.listing) { }
      ],
      alignment: .bottomTrailing
    )
  }
}

#Preview("FAB Menu - Two Items") {
  @Previewable @State var showMenu = false

  ZStack {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    Text("Tap the + button")
      .font(DS.Typography.body)
      .foregroundStyle(.secondary)

    FABMenuOverlay(
      isPresented: $showMenu,
      items: [
        FABMenuItem(title: "New Property", icon: DS.Icons.Entity.property) { },
        FABMenuItem(title: "New Listing", icon: DS.Icons.Entity.listing) { }
      ],
      alignment: .bottomTrailing
    )
  }
}

#Preview("FAB Menu - Dark Mode") {
  @Previewable @State var showMenu = false

  ZStack {
    DS.Colors.Background.grouped
      .ignoresSafeArea()

    Text("Tap the + button")
      .font(DS.Typography.body)
      .foregroundStyle(.secondary)

    FABMenuOverlay(
      isPresented: $showMenu,
      items: [
        FABMenuItem(title: "New Task", icon: DS.Icons.Entity.task) { },
        FABMenuItem(title: "New Activity", icon: DS.Icons.Entity.activity) { },
        FABMenuItem(title: "New Listing", icon: DS.Icons.Entity.listing) { }
      ],
      alignment: .bottomTrailing
    )
  }
  .preferredColorScheme(.dark)
}
