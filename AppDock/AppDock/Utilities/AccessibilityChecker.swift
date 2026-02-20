import ApplicationServices
import AppKit

struct AccessibilityChecker {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessIfNeeded() {
        guard !isTrusted else { return }
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
