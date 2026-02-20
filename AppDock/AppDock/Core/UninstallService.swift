import AppKit
import SwiftData

@MainActor
final class UninstallService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func canUninstall(_ app: AppItem) -> Bool {
        // Never uninstall system apps
        if app.isSystemApp { return false }

        // Never uninstall self
        if app.bundleIdentifier == Bundle.main.bundleIdentifier { return false }

        // Never uninstall running apps
        let runningApps = NSWorkspace.shared.runningApplications
        if runningApps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            return false
        }

        return true
    }

    func uninstall(_ app: AppItem) async -> Result<Void, UninstallError> {
        guard canUninstall(app) else {
            return .failure(.protected)
        }

        do {
            try await NSWorkspace.shared.recycle([app.url])
            cleanupSwiftData(bundleID: app.bundleIdentifier)
            return .success(())
        } catch {
            return .failure(.failed(error.localizedDescription))
        }
    }

    private func cleanupSwiftData(bundleID: String) {
        // Remove AppPreference
        let allPrefs = (try? modelContext.fetch(FetchDescriptor<AppPreference>())) ?? []
        for pref in allPrefs where pref.bundleIdentifier == bundleID {
            modelContext.delete(pref)
        }

        // Remove UsageRecords
        let allRecords = (try? modelContext.fetch(FetchDescriptor<UsageRecord>())) ?? []
        for record in allRecords where record.bundleIdentifier == bundleID {
            modelContext.delete(record)
        }

        // Remove LLM cache
        let allCache = (try? modelContext.fetch(FetchDescriptor<LLMClassificationCache>())) ?? []
        for entry in allCache where entry.bundleIdentifier == bundleID {
            modelContext.delete(entry)
        }

        try? modelContext.save()
    }
}

enum UninstallError: Error, LocalizedError {
    case protected
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .protected: "This app cannot be uninstalled."
        case .failed(let message): "Could not uninstall: \(message)"
        }
    }
}
