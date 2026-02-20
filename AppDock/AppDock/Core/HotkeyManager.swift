import Cocoa
import Carbon.HIToolbox

@MainActor
final class HotkeyManager {
    var onToggle: (() -> Void)?

    private var hotkeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    // -1 means no hotkey configured
    private(set) var keyCode: Int = -1
    private(set) var modifierFlags: CGEventFlags = []

    private static let hotkeyID = EventHotKeyID(
        signature: OSType(0x4150_4B44), // "APKD"
        id: 1
    )

    func start() {
        guard hotkeyRef == nil, keyCode >= 0 else { return }
        installHandler()
        registerHotkey()
    }

    func stop() {
        unregisterHotkey()
        removeHandler()
    }

    func updateHotkey(keyCode: Int, modifierFlags: CGEventFlags) {
        let wasRunning = hotkeyRef != nil
        if wasRunning { unregisterHotkey() }

        self.keyCode = keyCode
        self.modifierFlags = modifierFlags

        if wasRunning && keyCode >= 0 { registerHotkey() }
    }

    // MARK: - Carbon Event Handler

    private func installHandler() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, refcon -> OSStatus in
                guard let refcon, let event else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()

                var hotkeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    UInt32(kEventParamDirectObject),
                    UInt32(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )

                guard status == noErr, hotkeyID.id == HotkeyManager.hotkeyID.id else {
                    return OSStatus(eventNotHandledErr)
                }

                MainActor.assumeIsolated {
                    manager.onToggle?()
                }
                return noErr
            },
            1,
            &eventType,
            refcon,
            &eventHandlerRef
        )
    }

    private func removeHandler() {
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
        }
        eventHandlerRef = nil
    }

    // MARK: - Hotkey Registration

    private func registerHotkey() {
        guard keyCode >= 0 else { return }

        let id = HotkeyManager.hotkeyID
        let carbonModifiers = carbonModifierFlags(from: modifierFlags)

        let status = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status != noErr {
            print("[HotkeyManager] Failed to register hotkey (status: \(status))")
        }
    }

    private func unregisterHotkey() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
        }
        hotkeyRef = nil
    }

    // MARK: - Modifier Conversion

    private func carbonModifierFlags(from flags: CGEventFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.maskCommand)   { carbon |= UInt32(cmdKey) }
        if flags.contains(.maskShift)     { carbon |= UInt32(shiftKey) }
        if flags.contains(.maskAlternate) { carbon |= UInt32(optionKey) }
        if flags.contains(.maskControl)   { carbon |= UInt32(controlKey) }
        return carbon
    }
}
