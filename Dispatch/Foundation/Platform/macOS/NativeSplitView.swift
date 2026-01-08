
import SwiftUI

#if os(macOS)
/// A native NSSplitView wrapper for "Steve Jobs Quality" sidebar resizing.
/// Replaces the custom GeometryReader implementation for true 60fps performance.

/// Separate UIViewControllerRepresentable (macOS uses NSViewControllerRepresentable)
/// Separate UIViewControllerRepresentable (macOS uses NSViewControllerRepresentable)
struct NativeSplitView<Sidebar: View, Content: View>: NSViewControllerRepresentable {
  @ViewBuilder let sidebar: Sidebar
  @ViewBuilder let content: Content

  func makeNSViewController(context _: Context) -> DispatchSplitViewController {
    // Initialize with hosting controllers
    let sidebarVC = NSHostingController(rootView: sidebar)
    let contentVC = NSHostingController(rootView: content)

    return DispatchSplitViewController(sidebarVC: sidebarVC, contentVC: contentVC)
  }

  func updateNSViewController(_ nsViewController: DispatchSplitViewController, context _: Context) {
    // Update the hosting controllers' root views
    if let sidebarVC = nsViewController.sidebarItem.viewController as? NSHostingController<Sidebar> {
      sidebarVC.rootView = sidebar
    }
    if let contentVC = nsViewController.contentItem.viewController as? NSHostingController<Content> {
      contentVC.rootView = content
    }
  }
}

/// Custom SplitViewController to handle:
/// - Safe area ignorance (Full Height)
/// - Keyboard shortcuts (Cmd+/) via NotificationCenter
/// - Window edge alignment
final class DispatchSplitViewController: NSSplitViewController {

  // MARK: Lifecycle

  init(sidebarVC: NSViewController, contentVC: NSViewController) {
    // Sidebar Item
    sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
    sidebarItem.canCollapse = true
    sidebarItem.minimumThickness = DS.Spacing.sidebarMinWidth
    sidebarItem.maximumThickness = DS.Spacing.sidebarMaxWidth
    sidebarItem.holdingPriority = .defaultLow
    sidebarItem.collapseBehavior = .useConstraints

    // Content Item
    contentItem = NSSplitViewItem(viewController: contentVC)
    contentItem.minimumThickness = 300
    contentItem.holdingPriority = .defaultHigh

    super.init(nibName: nil, bundle: nil)

    addSplitViewItem(sidebarItem)
    addSplitViewItem(contentItem)
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    if let observer = toggleObserver {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  // MARK: Internal

  let sidebarItem: NSSplitViewItem
  let contentItem: NSSplitViewItem

  override func viewDidLoad() {
    super.viewDidLoad()

    // Configure SplitView
    splitView.isVertical = true
    splitView.dividerStyle = .thin

    // OPTIONAL: Make sidebar background translucent/full height
    // This requires the sidebar View to ignore safe areas, AND the window to be fullSizeContentView.

    // Observe Sidebar Toggle Notification
    toggleObserver = NotificationCenter.default.addObserver(
      forName: .toggleSidebar,
      object: nil,
      queue: .main,
    ) { [weak self] _ in
      self?.toggleSidebar(nil)
    }
  }

  override func viewDidLayout() {
    super.viewDidLayout()
    // Force the splitView to fill the view completely
    splitView.frame = view.bounds
  }

  override func toggleSidebar(_ sender: Any?) {
    // Native toggle implementation
    // This will collapse/expand the sidebar item
    super.toggleSidebar(sender)
  }

  // MARK: Private

  private var toggleObserver: Any?

}
#endif
