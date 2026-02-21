import Foundation
import SwiftData

@MainActor
final class AppStateTracker {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func annotate(_ apps: [AppItem]) -> [AppItem] {
        let settings = SettingsHelper.getOrCreate(context: modelContext)

        // Build lookup of existing preferences
        let descriptor = FetchDescriptor<AppPreference>()
        let allPrefs = (try? modelContext.fetch(descriptor)) ?? []
        var prefsByID = [String: AppPreference]()
        for pref in allPrefs {
            prefsByID[pref.bundleIdentifier] = pref
        }

        // First scan: treat all apps as baseline (no dots)
        let isInitialScan = !settings.hasPerformedInitialScan
        if isInitialScan {
            settings.hasPerformedInitialScan = true
        }

        var result = apps
        for i in result.indices {
            let app = result[i]
            let bundleID = app.bundleIdentifier

            if let pref = prefsByID[bundleID] {
                // Apply persisted category override
                if let overrideRaw = pref.categoryOverride,
                   let overrideCategory = AppCategory(rawValue: overrideRaw) {
                    result[i].category = overrideCategory
                }

                if pref.isNewApp {
                    // Not yet launched since being marked new
                    result[i].isNew = true
                } else if pref.isUpdatedApp {
                    // Not yet launched since being marked updated
                    result[i].isUpdated = true
                } else if let appVersion = app.version,
                          let knownVersion = pref.lastKnownVersion,
                          appVersion != knownVersion {
                    // Version changed since last launch
                    pref.isUpdatedApp = true
                    pref.lastKnownVersion = appVersion
                    result[i].isUpdated = true
                }
            } else {
                // Brand new app — insert preference
                let pref = AppPreference(bundleIdentifier: bundleID)
                pref.lastKnownVersion = app.version
                if !isInitialScan {
                    pref.isNewApp = true
                    result[i].isNew = true
                }
                modelContext.insert(pref)
            }
        }

        try? modelContext.save()
        return result
    }

    func recordLaunch(of app: AppItem) {
        let bundleID = app.bundleIdentifier
        var descriptor = FetchDescriptor<AppPreference>(
            predicate: #Predicate { $0.bundleIdentifier == bundleID }
        )
        descriptor.fetchLimit = 1

        let pref: AppPreference
        if let existing = try? modelContext.fetch(descriptor).first {
            pref = existing
        } else {
            pref = AppPreference(bundleIdentifier: bundleID)
            modelContext.insert(pref)
        }

        pref.isNewApp = false
        pref.isUpdatedApp = false
        pref.lastKnownVersion = app.version
        try? modelContext.save()
    }
}
