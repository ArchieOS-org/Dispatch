
import SwiftUI

#if os(macOS)
/// A background view that attaches a local event monitor to the window
struct KeyMonitorView: NSViewRepresentable {
    let handler: (NSEvent) -> NSEvent?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(handler: handler)
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.installMonitor()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    class Coordinator {
        let handler: (NSEvent) -> NSEvent?
        private var monitor: Any?
        
        init(handler: @escaping (NSEvent) -> NSEvent?) {
            self.handler = handler
        }
        
        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                return self?.handler(event) ?? event
            }
        }
        
        deinit {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
#endif
