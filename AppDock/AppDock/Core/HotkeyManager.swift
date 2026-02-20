import Cocoa
import Carbon.HIToolbox

@MainActor
final class HotkeyManager {
    var onToggle: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // -1 means no hotkey configured
    nonisolated(unsafe) private(set) var keyCode: Int = -1
    nonisolated(unsafe) private(set) var modifierFlags: CGEventFlags = []

    func start() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(event)
            },
            userInfo: refcon
        ) else {
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
    }

    func updateHotkey(keyCode: Int, modifierFlags: CGEventFlags) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
    }

    nonisolated private func handleEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        guard keyCode >= 0 else { return Unmanaged.passRetained(event) }

        let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        let allModifiers: CGEventFlags = [.maskCommand, .maskControl, .maskShift, .maskAlternate]
        let activeModifiers = flags.intersection(allModifiers)

        if code == keyCode && activeModifiers == modifierFlags {
            MainActor.assumeIsolated {
                onToggle?()
            }
            return nil // Consume the event
        }

        return Unmanaged.passRetained(event)
    }
}
