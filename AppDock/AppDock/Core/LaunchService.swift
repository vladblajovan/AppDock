import AppKit

@MainActor
final class LaunchService {
    func launch(_ app: AppItem) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.openApplication(at: app.url, configuration: configuration) { _, error in
            if let error {
                print("Failed to launch \(app.name): \(error.localizedDescription)")
            }
        }
    }
}
