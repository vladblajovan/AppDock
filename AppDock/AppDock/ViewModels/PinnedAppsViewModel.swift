import SwiftUI
import SwiftData

@MainActor
@Observable
final class PinnedAppsViewModel {
    var pinnedApps: [AppItem] = []

    private let modelContext: ModelContext
    private let maxPinned = 12

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var pinnedBundleIDs: Set<String> {
        Set(pinnedApps.map(\.bundleIdentifier))
    }

    var isEmpty: Bool { pinnedApps.isEmpty }

    func loadPinnedApps(from allApps: [AppItem]) {
        let descriptor = FetchDescriptor<AppPreference>(
            predicate: #Predicate<AppPreference> { $0.isPinned },
            sortBy: [SortDescriptor(\.pinOrder)]
        )

        guard let prefs = try? modelContext.fetch(descriptor) else { return }

        pinnedApps = prefs.compactMap { pref in
            allApps.first(where: { $0.bundleIdentifier == pref.bundleIdentifier })
        }
    }

    func pinApp(_ app: AppItem) {
        guard !pinnedBundleIDs.contains(app.bundleIdentifier) else { return }
        guard pinnedApps.count < maxPinned else { return }

        let pref = getOrCreatePreference(for: app.bundleIdentifier)
        pref.isPinned = true
        pref.pinOrder = pinnedApps.count
        save()

        pinnedApps.append(app)
    }

    func unpinApp(_ app: AppItem) {
        let pref = getOrCreatePreference(for: app.bundleIdentifier)
        pref.isPinned = false
        pref.pinOrder = 0
        save()

        pinnedApps.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
        reindexPinOrder()
    }

    func movePinnedApp(from source: IndexSet, to destination: Int) {
        pinnedApps.move(fromOffsets: source, toOffset: destination)
        reindexPinOrder()
    }

    // MARK: - Private

    private func getOrCreatePreference(for bundleID: String) -> AppPreference {
        let fetchAll = FetchDescriptor<AppPreference>()
        let allPrefs = (try? modelContext.fetch(fetchAll)) ?? []
        if let existing = allPrefs.first(where: { $0.bundleIdentifier == bundleID }) {
            return existing
        }
        let pref = AppPreference(bundleIdentifier: bundleID)
        modelContext.insert(pref)
        return pref
    }

    private func reindexPinOrder() {
        let fetchAll = FetchDescriptor<AppPreference>()
        let allPrefs = (try? modelContext.fetch(fetchAll)) ?? []

        for (index, app) in pinnedApps.enumerated() {
            if let pref = allPrefs.first(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
                pref.pinOrder = index
            }
        }
        save()
    }

    private func save() {
        try? modelContext.save()
    }
}
