import SwiftUI
import Carbon.HIToolbox

struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var keyCode: Int
    @Binding var modifiers: Int

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.keyCode = keyCode
        view.modifiers = modifiers
        view.onHotkeyRecorded = { newKeyCode, newModifiers in
            keyCode = newKeyCode
            modifiers = newModifiers
        }
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.keyCode = keyCode
        nsView.modifiers = modifiers
        nsView.needsDisplay = true
    }
}

final class HotkeyRecorderNSView: NSView {
    var keyCode: Int = -1
    var modifiers: Int = 0
    var onHotkeyRecorded: ((Int, Int) -> Void)?

    private var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 120, height: 24)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bgColor: NSColor = isRecording ? .controlAccentColor.withAlphaComponent(0.15) : .quaternaryLabelColor
        bgColor.setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
        path.fill()

        if isRecording {
            NSColor.controlAccentColor.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }

        let text: String
        if isRecording {
            text = "Press shortcut..."
        } else if keyCode < 0 {
            text = "Click to record"
        } else {
            text = displayString(keyCode: keyCode, modifiers: modifiers)
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: isRecording ? NSColor.controlAccentColor : NSColor.labelColor,
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let textSize = attrStr.size()
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        attrStr.draw(in: textRect)
    }

    override func mouseDown(with event: NSEvent) {
        if !isRecording {
            isRecording = true
            window?.makeFirstResponder(self)
            needsDisplay = true
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        // Escape cancels recording
        if event.keyCode == UInt16(kVK_Escape) {
            isRecording = false
            needsDisplay = true
            return
        }

        // Require at least one modifier
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !mods.isEmpty else { return }

        let newKeyCode = Int(event.keyCode)
        let newModifiers = Int(mods.carbonFlags)

        keyCode = newKeyCode
        modifiers = newModifiers
        isRecording = false
        needsDisplay = true
        onHotkeyRecorded?(newKeyCode, newModifiers)
    }

    override func flagsChanged(with event: NSEvent) {
        // Ignore pure modifier presses
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        needsDisplay = true
        return super.resignFirstResponder()
    }

    private func displayString(keyCode: Int, modifiers: Int) -> String {
        let flags = CGEventFlags(rawValue: UInt64(modifiers))
        var parts: [String] = []
        if flags.contains(.maskControl) { parts.append("⌃") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskShift) { parts.append("⇧") }
        if flags.contains(.maskCommand) { parts.append("⌘") }
        parts.append(keyCodeName(keyCode))
        return parts.joined()
    }

    private func keyCodeName(_ code: Int) -> String {
        let keyNames: [Int: String] = [
            kVK_Space: "Space",
            kVK_Return: "Return",
            kVK_Tab: "Tab",
            kVK_Delete: "Delete",
            kVK_ForwardDelete: "⌦",
            kVK_Escape: "Esc",
            kVK_UpArrow: "↑",
            kVK_DownArrow: "↓",
            kVK_LeftArrow: "←",
            kVK_RightArrow: "→",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
            kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
            kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
            kVK_Home: "Home", kVK_End: "End",
            kVK_PageUp: "PgUp", kVK_PageDown: "PgDn",
        ]

        if let name = keyNames[code] {
            return name
        }

        // Use TISCopyCurrentKeyboardInputSource to map keyCode to character
        if let currentKeyboard = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
           let layoutDataPtr = TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData) {
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

            if length > 0 {
                return String(utf16CodeUnits: chars, count: length).uppercased()
            }
        }

        return "Key\(code)"
    }
}

private extension NSEvent.ModifierFlags {
    var carbonFlags: Int {
        var result = 0
        if contains(.command) { result |= Int(CGEventFlags.maskCommand.rawValue) }
        if contains(.option) { result |= Int(CGEventFlags.maskAlternate.rawValue) }
        if contains(.control) { result |= Int(CGEventFlags.maskControl.rawValue) }
        if contains(.shift) { result |= Int(CGEventFlags.maskShift.rawValue) }
        return result
    }
}
