import AppKit
@preconcurrency import ApplicationServices

@MainActor
@Observable
final class BadgeService {
    var badgeCounts: [String: Int] = [:]
    private var pollingTimer: Timer?

    var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermissionIfNeeded() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        let options = [key as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func startPolling(interval: TimeInterval = 5.0) {
        stopPolling()
        refresh()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        badgeCounts = [:]
    }

    func refresh() {
        guard isAccessibilityGranted else { return }

        var newCounts: [String: Int] = [:]

        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return
        }

        let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else {
            return
        }

        for child in children {
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)

            // Look for the list of dock items
            guard let role = roleRef as? String, role == kAXListRole else { continue }

            var itemsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &itemsRef) == .success,
                  let items = itemsRef as? [AXUIElement] else {
                continue
            }

            for item in items {
                // Get the URL to determine bundle ID
                var urlRef: CFTypeRef?
                guard AXUIElementCopyAttributeValue(item, "AXURL" as CFString, &urlRef) == .success,
                      let urlValue = urlRef else {
                    continue
                }

                let url: URL?
                if CFGetTypeID(urlValue) == CFURLGetTypeID() {
                    url = urlValue as! CFURL as URL
                } else if let str = urlValue as? String {
                    url = URL(string: str)
                } else {
                    continue
                }

                guard let appURL = url,
                      let bundle = Bundle(url: appURL),
                      let bundleID = bundle.bundleIdentifier else {
                    continue
                }

                // Get the status label (badge text)
                var statusRef: CFTypeRef?
                guard AXUIElementCopyAttributeValue(item, "AXStatusLabel" as CFString, &statusRef) == .success,
                      let statusLabel = statusRef as? String,
                      !statusLabel.isEmpty else {
                    continue
                }

                let count: Int
                if statusLabel.contains("+") {
                    count = 99
                } else if let parsed = Int(statusLabel) {
                    count = parsed
                } else {
                    continue
                }

                if count > 0 {
                    newCounts[bundleID] = count
                }
            }
        }

        badgeCounts = newCounts
    }
}
