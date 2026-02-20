import AppKit

@MainActor
final class DockService {
    func addToDock(_ app: AppItem) -> Bool {
        let plistPath = NSHomeDirectory() + "/Library/Preferences/com.apple.dock.plist"

        guard let plistData = FileManager.default.contents(atPath: plistPath),
              var plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              var persistentApps = plist["persistent-apps"] as? [[String: Any]] else {
            return false
        }

        // Check if already in Dock
        let appPath = app.url.path
        for entry in persistentApps {
            if let tileData = entry["tile-data"] as? [String: Any],
               let fileData = tileData["file-data"] as? [String: Any],
               let existingPath = fileData["_CFURLString"] as? String,
               existingPath.contains(appPath) {
                return false // Already in Dock
            }
        }

        // Build Dock entry
        let dockEntry: [String: Any] = [
            "tile-data": [
                "file-data": [
                    "_CFURLString": app.url.absoluteString,
                    "_CFURLStringType": 15,
                ],
                "file-label": app.name,
                "file-type": 41,
            ] as [String: Any],
            "tile-type": "file-tile",
        ]

        persistentApps.append(dockEntry)
        plist["persistent-apps"] = persistentApps

        // Write plist
        guard let updatedData = try? PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0) else {
            return false
        }

        guard FileManager.default.createFile(atPath: plistPath, contents: updatedData) else {
            return false
        }

        // Restart Dock to apply changes
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]
        try? process.run()

        return true
    }
}
