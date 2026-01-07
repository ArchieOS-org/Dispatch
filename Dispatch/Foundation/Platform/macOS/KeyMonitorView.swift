
import SwiftUI

#if os(macOS)
/// A background view that attaches a local event monitor to the window
struct KeyMonitorView: NSViewRepresentable {
  final class Coordinator {

    // MARK: Lifecycle

    init(handler: @escaping (NSEvent) -> NSEvent?) {
      self.handler = handler
    }

    deinit {
      if let monitor {
        NSEvent.removeMonitor(monitor)
      }
    }

    // MARK: Internal

    let handler: (NSEvent) -> NSEvent?

    func installMonitor() {
      guard monitor == nil else { return }
      monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        return self?.handler(event) ?? event
      }
    }

    // MARK: Private

    private var monitor: Any?

  }

  let handler: (NSEvent) -> NSEvent?

  func makeCoordinator() -> Coordinator {
    Coordinator(handler: handler)
  }

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    context.coordinator.installMonitor()
    return view
  }

  func updateNSView(_: NSView, context _: Context) { }

}
#endif
