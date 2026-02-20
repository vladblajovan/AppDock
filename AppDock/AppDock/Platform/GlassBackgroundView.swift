import SwiftUI

struct GlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            // Live behind-window content is provided by NSVisualEffectView
            // at the AppKit level (WindowManager). The .glassEffect adds the
            // Liquid Glass visual treatment on top.
            content
                .clipShape(RoundedRectangle(cornerRadius: PlatformStyle.panelCornerRadius))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: PlatformStyle.panelCornerRadius))
        } else {
            // On macOS 15, the NSVisualEffectView at the AppKit level handles
            // the live blur. Just clip the shape here.
            content
                .clipShape(RoundedRectangle(cornerRadius: PlatformStyle.panelCornerRadius))
        }
    }
}

extension View {
    func adaptiveGlassBackground() -> some View {
        modifier(GlassBackground())
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
