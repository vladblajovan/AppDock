import SwiftUI
import SwiftData
import Carbon.HIToolbox

@main
struct AppDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hotkeyKeyCode") private var hotkeyKeyCode: Int = -1
    @AppStorage("hotkeyModifiers") private var hotkeyModifiers: Int = 0

    var body: some Scene {
        MenuBarExtra("AppDock", systemImage: "square.grid.3x3.fill") {
            Button("Show AppDock") {
                appDelegate.windowManager.togglePanel()
            }
            .modifier(DynamicHotkeyModifier(
                keyCode: hotkeyKeyCode,
                modifiers: hotkeyModifiers
            ))

            Divider()

            Button("Settings...") {
                appDelegate.showSettings()
            }
            .keyboardShortcut(",")

            Button("Quit AppDock") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let windowManager = WindowManager()
    let hotkeyManager = HotkeyManager()
    private var settingsWindow: NSWindow?

    let modelContainer: ModelContainer = {
        return try! ModelContainer(for:
            UsageRecord.self,
            AppPreference.self,
            LLMClassificationCache.self,
            AppSettings.self
        )
    }()

    private var launcherViewModel: LauncherViewModel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        let modelContext = modelContainer.mainContext

        // Create services
        let appScanner = AppScanner()
        let classifier = CategoryClassifier()
        let launchService = LaunchService()

        // Create root ViewModel with injected services
        launcherViewModel = LauncherViewModel(
            appScanner: appScanner,
            classifier: classifier,
            launchService: launchService,
            modelContext: modelContext
        )

        launcherViewModel.onDismiss = { [weak self] in
            self?.windowManager.hidePanel()
        }
        windowManager.setContentView(LauncherView(viewModel: launcherViewModel))

        // Load settings and apply theme + hotkey
        let settings = SettingsHelper.getOrCreate(context: modelContext)
        let theme = AppTheme(rawValue: settings.theme) ?? .system
        windowManager.theme = theme

        // Sync SwiftData values to UserDefaults so @AppStorage in menu bar stays current
        UserDefaults.standard.set(settings.hotkeyKeyCode, forKey: "hotkeyKeyCode")
        UserDefaults.standard.set(settings.hotkeyModifiers, forKey: "hotkeyModifiers")
        hotkeyManager.updateHotkey(
            keyCode: settings.hotkeyKeyCode,
            modifierFlags: CGEventFlags(rawValue: UInt64(settings.hotkeyModifiers))
        )

        hotkeyManager.onToggle = { [weak self] in
            self?.windowManager.togglePanel()
        }

        hotkeyManager.start()
    }

    private func applyTheme(_ theme: AppTheme) {
        windowManager.theme = theme
        windowManager.applyTheme()
        settingsWindow?.appearance = theme.nsAppearance
    }

    func showSettings() {
        if let existing = settingsWindow, existing.isVisible {
            NSApp.setActivationPolicy(.regular)
            existing.orderFrontRegardless()
            existing.makeKey()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsVM = SettingsViewModel(modelContext: modelContainer.mainContext)
        settingsVM.onThemeChanged = { [weak self] theme in
            self?.applyTheme(theme)
        }
        settingsVM.onHotkeyChanged = { [weak self] keyCode, modifiers in
            UserDefaults.standard.set(keyCode, forKey: "hotkeyKeyCode")
            UserDefaults.standard.set(modifiers, forKey: "hotkeyModifiers")
            self?.hotkeyManager.updateHotkey(
                keyCode: keyCode,
                modifierFlags: CGEventFlags(rawValue: UInt64(modifiers))
            )
        }
        let settingsView = SettingsView(viewModel: settingsVM)
        let hostingView = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 350),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AppDock Settings"
        window.level = .floating + 1
        window.appearance = windowManager.theme.nsAppearance
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        settingsWindow = window

        NSApp.setActivationPolicy(.regular)
        window.orderFrontRegardless()
        window.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === settingsWindow {
            settingsWindow = nil
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        windowManager.togglePanel()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.stop()
    }
}

struct DynamicHotkeyModifier: ViewModifier {
    let keyCode: Int
    let modifiers: Int

    func body(content: Content) -> some View {
        if let key = keyEquivalent(for: keyCode) {
            content.keyboardShortcut(key, modifiers: eventModifiers(from: modifiers))
        } else {
            content
        }
    }

    private func eventModifiers(from carbonFlags: Int) -> SwiftUI.EventModifiers {
        let flags = CGEventFlags(rawValue: UInt64(carbonFlags))
        var result: SwiftUI.EventModifiers = []
        if flags.contains(.maskCommand) { result.insert(.command) }
        if flags.contains(.maskAlternate) { result.insert(.option) }
        if flags.contains(.maskControl) { result.insert(.control) }
        if flags.contains(.maskShift) { result.insert(.shift) }
        return result
    }

    private func keyEquivalent(for code: Int) -> KeyEquivalent? {
        switch code {
        case kVK_Space: return .space
        case kVK_Return: return .return
        case kVK_Tab: return .tab
        case kVK_Delete: return .delete
        case kVK_Escape: return .escape
        case kVK_UpArrow: return .upArrow
        case kVK_DownArrow: return .downArrow
        case kVK_LeftArrow: return .leftArrow
        case kVK_RightArrow: return .rightArrow
        case kVK_Home: return .home
        case kVK_End: return .end
        case kVK_PageUp: return .pageUp
        case kVK_PageDown: return .pageDown
        default:
            guard code >= 0 else { return nil }
            guard let currentKeyboard = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
                  let layoutDataPtr = TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData)
            else { return nil }

            let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPtr).takeUnretainedValue() as Data
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length: Int = 0

            layoutData.withUnsafeBytes { rawBuf in
                let layoutPtr = rawBuf.bindMemory(to: UCKeyboardLayout.self).baseAddress!
                UCKeyTranslate(
                    layoutPtr,
                    UInt16(code),
                    UInt16(kUCKeyActionDisplay),
                    0,
                    UInt32(LMGetKbdType()),
                    UInt32(kUCKeyTranslateNoDeadKeysBit),
                    &deadKeyState,
                    chars.count,
                    &length,
                    &chars
                )
            }

            guard length > 0 else { return nil }
            let str = String(utf16CodeUnits: chars, count: length).lowercased()
            guard let char = str.first else { return nil }
            return KeyEquivalent(char)
        }
    }
}

struct SettingsHelper {
    static func getOrCreate(context: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        try? context.save()
        return settings
    }
}
