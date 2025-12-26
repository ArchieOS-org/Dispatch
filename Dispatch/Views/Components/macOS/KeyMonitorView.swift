
import SwiftUI

#if os(macOS)
/// A background view that attaches a local event monitor to the window
struct KeyMonitorView: NSViewRepresentable {
    let handler: (NSEvent) -> NSEvent?
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            // Monitor local events (Application level, but filtered to active window by logic if needed)
            // .local monitor only works when app is active, which is what we want.
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                return self.handler(event)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
