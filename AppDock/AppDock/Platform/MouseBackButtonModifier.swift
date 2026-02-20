import SwiftUI

struct MouseBackButtonModifier: ViewModifier {
    let action: () -> Void

    @State private var mouseMonitor: Any?
    @State private var swipeMonitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                // Mouse back button (button 3 on most mice)
                mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { event in
                    if event.buttonNumber == 3 {
                        action()
                        return nil
                    }
                    return event
                }
                // Some mice send back as a swipe event instead
                swipeMonitor = NSEvent.addLocalMonitorForEvents(matching: .swipe) { event in
                    if event.deltaX > 0 {
                        action()
                        return nil
                    }
                    return event
                }
            }
            .onDisappear {
                if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
                if let swipeMonitor { NSEvent.removeMonitor(swipeMonitor) }
                self.mouseMonitor = nil
                self.swipeMonitor = nil
            }
    }
}

extension View {
    func onMouseBackButton(perform action: @escaping () -> Void) -> some View {
        modifier(MouseBackButtonModifier(action: action))
    }
}
