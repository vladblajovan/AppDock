import Foundation

@MainActor
final class AppScanner {
    var onAppsChanged: (([AppItem]) -> Void)?

    private var knownApps: [String: AppItem] = [:]  // bundleID → AppItem
    private var fsSources: [DispatchSourceFileSystemObject] = []
    private var fileDescriptors: [Int32] = []
    private var debounceWorkItem: DispatchWorkItem?

    private static let scanPaths = [
        "/Applications",
        "/Applications/Utilities",
        "/System/Applications",
        "/System/Applications/Utilities",
        NSHomeDirectory() + "/Applications",
        "/opt/homebrew/Caskroom",
    ]

    private static let systemBundleIDPrefixes: Set<String> = [
        "com.apple.SetupAssistant",
        "com.apple.FeedbackAssistant",
        "com.apple.loginwindow",
        "com.apple.finder",
    ]

    func scan() -> [AppItem] {
        var apps: [String: AppItem] = [:]

        for path in Self.scanPaths {
            let url = URL(fileURLWithPath: path)
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "app" else { continue }

                // Resolve symlinks to avoid double-counting Homebrew apps
                let resolvedURL = fileURL.resolvingSymlinksInPath()

                guard let metadata = AppMetadataParser.parse(bundleURL: resolvedURL) else { continue }

                // Skip UI elements and background-only apps
                if metadata.isUIElement || metadata.isBackgroundOnly { continue }

                // Skip known system helper apps
                if Self.systemBundleIDPrefixes.contains(where: { metadata.bundleIdentifier.hasPrefix($0) }) {
                    continue
                }

                // Avoid duplicates (keep first found)
                guard apps[metadata.bundleIdentifier] == nil else { continue }

                let isSystem = resolvedURL.path.hasPrefix("/System/Applications")

                let app = AppItem(
                    id: metadata.bundleIdentifier,
                    name: metadata.displayName,
                    bundleIdentifier: metadata.bundleIdentifier,
                    url: resolvedURL,
                    appStoreCategory: metadata.appStoreCategory,
                    category: .other,  // Will be classified later
                    isSystemApp: isSystem
                )
                apps[metadata.bundleIdentifier] = app
            }
        }

        knownApps = apps
        return Array(apps.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func startMonitoring() {
        stopMonitoring()

        for path in Self.scanPaths {
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else { continue }

            fileDescriptors.append(fd)

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete],
                queue: .main
            )

            source.setEventHandler { [weak self] in
                self?.handleFileSystemChange()
            }

            source.setCancelHandler {
                close(fd)
            }

            source.resume()
            fsSources.append(source)
        }
    }

    func stopMonitoring() {
        for source in fsSources {
            source.cancel()
        }
        fsSources.removeAll()
        fileDescriptors.removeAll()
    }

    private func handleFileSystemChange() {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let apps = self.scan()
            self.onAppsChanged?(apps)
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
}
