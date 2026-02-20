import AppKit

enum AppTheme: String, CaseIterable, Codable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

struct AdaptivePanelConfigurator {
    static func configure(_ panel: NSPanel, theme: AppTheme) {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.styleMask = [.nonactivatingPanel, .fullSizeContentView, .borderless, .resizable]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false

        panel.appearance = theme.nsAppearance

        if #available(macOS 26, *) {
            // On macOS 26, let SwiftUI's .glassEffect handle everything.
            // The window must be fully transparent with no layer clipping
            // so the glass can sample the content behind the window live.
            panel.hasShadow = false
            panel.contentView?.wantsLayer = true
            panel.contentView?.layer?.cornerRadius = 0
            panel.contentView?.layer?.masksToBounds = false
        } else {
            panel.hasShadow = true
            panel.contentView?.wantsLayer = true
            panel.contentView?.layer?.cornerRadius = PlatformStyle.panelCornerRadius
            panel.contentView?.layer?.masksToBounds = true
        }
    }
}
