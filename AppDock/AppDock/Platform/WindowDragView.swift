import SwiftUI

struct WindowDragView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = WindowDraggableView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class WindowDraggableView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
