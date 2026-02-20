import AppKit
import SwiftUI

@MainActor
final class WindowManager {
    private var panel: NSPanel?
    private var clickOutsideMonitor: Any?
    private(set) var isVisible = false
    private var lastHideTime: Date = .distantPast
    var theme: AppTheme = .system

    func togglePanel() {
        if isVisible {
            hidePanel()
        } else if Date().timeIntervalSince(lastHideTime) > 0.5 {
            showPanel()
        }
    }

    private static let panelHeightKey = "AppDock.panelHeight"
    private static let panelOriginXKey = "AppDock.panelOriginX"
    private static let panelOriginYKey = "AppDock.panelOriginY"

    func showPanel() {
        let panel = getOrCreatePanel()
        AdaptivePanelConfigurator.configure(panel, theme: theme)

        let savedHeight = UserDefaults.standard.double(forKey: Self.panelHeightKey)
        let height = savedHeight > 0 ? max(400, min(savedHeight, 1200)) : PlatformStyle.panelHeight

        let screenFrame = activeScreenFrame()
        let panelSize = NSSize(width: PlatformStyle.panelWidth, height: height)

        let origin: NSPoint
        let defaults = UserDefaults.standard
        let savedX = defaults.double(forKey: Self.panelOriginXKey)
        let savedY = defaults.double(forKey: Self.panelOriginYKey)
        let savedCenter = NSPoint(x: savedX + panelSize.width / 2, y: savedY + panelSize.height / 2)
        let savedPositionVisible = defaults.object(forKey: Self.panelOriginXKey) != nil
            && NSScreen.screens.contains(where: { $0.visibleFrame.contains(savedCenter) })
        if savedPositionVisible {
            origin = NSPoint(x: savedX, y: savedY)
        } else {
            origin = NSPoint(
                x: screenFrame.midX - panelSize.width / 2,
                y: screenFrame.midY - panelSize.height / 2 + screenFrame.height * 0.1
            )
        }

        (panel as? KeyablePanel)?.suppressFrameSave = true
        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
        (panel as? KeyablePanel)?.suppressFrameSave = false
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        panel.makeKey()

        isVisible = true
        startClickOutsideMonitor()
    }

    func hidePanel() {
        guard let panel, isVisible else { return }

        isVisible = false
        lastHideTime = Date()
        stopClickOutsideMonitor()
        panel.alphaValue = 0
        panel.orderOut(nil)
    }

    private func startClickOutsideMonitor() {
        stopClickOutsideMonitor()
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.hidePanel()
            }
        }
    }

    private func stopClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }

    func applyTheme() {
        guard let panel else { return }
        panel.appearance = theme.nsAppearance
    }

    func setContentView(_ view: some View) {
        let panel = getOrCreatePanel()
        let hostingView = NSHostingView(rootView: view)

        if #available(macOS 26, *) {
            // On macOS 26, SwiftUI's .glassEffect handles the visual treatment.
            // But we still need an NSVisualEffectView with .behindWindow blending
            // to keep the window server sending live behind-window content even
            // when the panel is not focused. We make it invisible (alphaValue = 0)
            // so it doesn't affect the glass appearance.
            let container = NSView(frame: NSRect(x: 0, y: 0, width: PlatformStyle.panelWidth, height: PlatformStyle.panelHeight))

            let effectView = NSVisualEffectView(frame: container.bounds)
            effectView.blendingMode = .behindWindow
            effectView.state = .active
            effectView.material = .underWindowBackground
            effectView.alphaValue = 0.01
            effectView.autoresizingMask = [.width, .height]
            effectView.wantsLayer = true
            effectView.layer?.cornerRadius = PlatformStyle.panelCornerRadius
            effectView.layer?.masksToBounds = true
            container.addSubview(effectView)

            hostingView.frame = container.bounds
            hostingView.autoresizingMask = [.width, .height]
            container.addSubview(hostingView)

            panel.contentView = container
        } else {
            // On macOS 15, use NSVisualEffectView with .behindWindow blending
            // for live behind-window transparency.
            let container = NSView(frame: NSRect(x: 0, y: 0, width: PlatformStyle.panelWidth, height: PlatformStyle.panelHeight))

            let effectView = NSVisualEffectView(frame: container.bounds)
            effectView.blendingMode = .behindWindow
            effectView.state = .active
            effectView.material = PlatformStyle.sequoiaMaterial
            effectView.autoresizingMask = [.width, .height]
            effectView.wantsLayer = true
            container.addSubview(effectView)

            hostingView.frame = container.bounds
            hostingView.autoresizingMask = [.width, .height]
            container.addSubview(hostingView)

            container.wantsLayer = true
            container.layer?.cornerRadius = PlatformStyle.panelCornerRadius
            container.layer?.masksToBounds = true

            panel.contentView = container
        }

        AdaptivePanelConfigurator.configure(panel, theme: theme)
    }

    // MARK: - Private

    private func getOrCreatePanel() -> NSPanel {
        if let existing = panel { return existing }

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: PlatformStyle.panelWidth, height: PlatformStyle.panelHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: PlatformStyle.panelWidth, height: 400)
        panel.maxSize = NSSize(width: PlatformStyle.panelWidth, height: 1200)
        panel.onResize = { size in
            UserDefaults.standard.set(size.height, forKey: WindowManager.panelHeightKey)
        }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak panel] _ in
            guard let origin = panel?.frame.origin,
                  panel?.suppressFrameSave != true else { return }
            UserDefaults.standard.set(origin.x, forKey: WindowManager.panelOriginXKey)
            UserDefaults.standard.set(origin.y, forKey: WindowManager.panelOriginYKey)
        }

        self.panel = panel
        return panel
    }

    private func activeScreenFrame() -> NSRect {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
        return screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }
}

/// NSPanel subclass that allows becoming key window for keyboard input (search field).
final class KeyablePanel: NSPanel {
    var onResize: ((NSSize) -> Void)?
    var suppressFrameSave = false

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        guard !suppressFrameSave else { return }
        onResize?(frameRect.size)
    }

    override func setFrame(_ frameRect: NSRect, display displayFlag: Bool, animate animateFlag: Bool) {
        super.setFrame(frameRect, display: displayFlag, animate: animateFlag)
        guard !suppressFrameSave else { return }
        onResize?(frameRect.size)
    }
}
