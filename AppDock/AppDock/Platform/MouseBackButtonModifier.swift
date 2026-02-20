import SwiftUI
import AppKit

struct MouseBackButtonModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .background(MouseBackButtonView(action: action))
    }
}

/// Uses an NSView to reliably tie event monitors to the view's actual lifecycle.
private struct MouseBackButtonView: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = MouseBackButtonNSView()
        view.action = action
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? MouseBackButtonNSView)?.action = action
    }
}

private final class MouseBackButtonNSView: NSView {
    var action: (() -> Void)?
    private var mouseMonitor: Any?
    private var swipeMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            addMonitors()
        } else {
            removeMonitors()
        }
    }

    private func addMonitors() {
        guard mouseMonitor == nil else { return }

        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
            if event.buttonNumber == 3 {
                self?.action?()
                return nil
            }
            return event
        }
        swipeMonitor = NSEvent.addLocalMonitorForEvents(matching: .swipe) { [weak self] event in
            if event.deltaX > 0 {
                self?.action?()
                return nil
            }
            return event
        }
    }

    private func removeMonitors() {
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        if let swipeMonitor { NSEvent.removeMonitor(swipeMonitor) }
        mouseMonitor = nil
        swipeMonitor = nil
    }

    deinit {
        removeMonitors()
    }
}

extension View {
    func onMouseBackButton(perform action: @escaping () -> Void) -> some View {
        modifier(MouseBackButtonModifier(action: action))
    }
}
