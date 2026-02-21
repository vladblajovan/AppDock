import Carbon.HIToolbox

struct HotkeyConflict {
    let displayName: String
    let settingsPath: String?
    let registrationFailed: Bool
}

enum HotkeyConflictChecker {
    private struct Entry {
        let keyCode: Int
        let modifiers: CGEventFlags
        let displayName: String
        let settingsPath: String?
    }

    private static let knownShortcuts: [Entry] = [
        // Spotlight
        Entry(keyCode: kVK_Space, modifiers: .maskCommand,
              displayName: "Spotlight",
              settingsPath: "Keyboard > Keyboard Shortcuts > Spotlight"),
        // Input Sources
        Entry(keyCode: kVK_Space, modifiers: .maskControl,
              displayName: "Input Sources",
              settingsPath: "Keyboard > Keyboard Shortcuts > Input Sources"),
        // App Switcher
        Entry(keyCode: kVK_Tab, modifiers: .maskCommand,
              displayName: "App Switcher", settingsPath: nil),
        // Quit App
        Entry(keyCode: kVK_ANSI_Q, modifiers: .maskCommand,
              displayName: "Quit App", settingsPath: nil),
        // Close Window
        Entry(keyCode: kVK_ANSI_W, modifiers: .maskCommand,
              displayName: "Close Window", settingsPath: nil),
        // Hide App
        Entry(keyCode: kVK_ANSI_H, modifiers: .maskCommand,
              displayName: "Hide App", settingsPath: nil),
        // Minimize
        Entry(keyCode: kVK_ANSI_M, modifiers: .maskCommand,
              displayName: "Minimize", settingsPath: nil),
        // Preferences
        Entry(keyCode: kVK_ANSI_Comma, modifiers: .maskCommand,
              displayName: "Preferences", settingsPath: nil),
        // Screenshots
        Entry(keyCode: kVK_ANSI_3, modifiers: [.maskCommand, .maskShift],
              displayName: "Screenshot (Full Screen)",
              settingsPath: "Keyboard > Keyboard Shortcuts > Screenshots"),
        Entry(keyCode: kVK_ANSI_4, modifiers: [.maskCommand, .maskShift],
              displayName: "Screenshot (Selection)",
              settingsPath: "Keyboard > Keyboard Shortcuts > Screenshots"),
        Entry(keyCode: kVK_ANSI_5, modifiers: [.maskCommand, .maskShift],
              displayName: "Screenshot / Recording",
              settingsPath: "Keyboard > Keyboard Shortcuts > Screenshots"),
        // Mission Control
        Entry(keyCode: kVK_UpArrow, modifiers: .maskControl,
              displayName: "Mission Control",
              settingsPath: "Keyboard > Keyboard Shortcuts > Mission Control"),
        Entry(keyCode: kVK_DownArrow, modifiers: .maskControl,
              displayName: "Application Windows",
              settingsPath: "Keyboard > Keyboard Shortcuts > Mission Control"),
        Entry(keyCode: kVK_LeftArrow, modifiers: .maskControl,
              displayName: "Move Space Left",
              settingsPath: "Keyboard > Keyboard Shortcuts > Mission Control"),
        Entry(keyCode: kVK_RightArrow, modifiers: .maskControl,
              displayName: "Move Space Right",
              settingsPath: "Keyboard > Keyboard Shortcuts > Mission Control"),
    ]

    static func check(keyCode: Int, modifiers: Int) -> HotkeyConflict? {
        let flags = CGEventFlags(rawValue: UInt64(modifiers))
        let relevantMask: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        let inputMods = flags.intersection(relevantMask)

        let knownConflict = knownShortcuts.first { entry in
            entry.keyCode == keyCode && entry.modifiers == inputMods
        }

        let regFailed = testRegistration(keyCode: keyCode, modifiers: modifiers)

        if let entry = knownConflict {
            return HotkeyConflict(
                displayName: entry.displayName,
                settingsPath: entry.settingsPath,
                registrationFailed: regFailed
            )
        }

        if regFailed {
            return HotkeyConflict(
                displayName: "another application or macOS",
                settingsPath: nil,
                registrationFailed: true
            )
        }

        return nil
    }

    /// Attempts to register the hotkey with Carbon and immediately unregisters it.
    /// Returns true if registration failed (the shortcut is taken by the system).
    private static func testRegistration(keyCode: Int, modifiers: Int) -> Bool {
        let flags = CGEventFlags(rawValue: UInt64(modifiers))
        var carbonMods: UInt32 = 0
        if flags.contains(.maskCommand)   { carbonMods |= UInt32(cmdKey) }
        if flags.contains(.maskShift)     { carbonMods |= UInt32(shiftKey) }
        if flags.contains(.maskAlternate) { carbonMods |= UInt32(optionKey) }
        if flags.contains(.maskControl)   { carbonMods |= UInt32(controlKey) }

        let testID = EventHotKeyID(signature: OSType(0x5445_5354), id: 9999) // "TEST"
        var hotkeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            UInt32(keyCode),
            carbonMods,
            testID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status == noErr, let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            return false
        }
        return true
    }
}
