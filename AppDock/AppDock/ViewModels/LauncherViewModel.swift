import SwiftUI
import SwiftData

enum AppViewMode: String, CaseIterable {
    case folders = "Folders"
    case list = "List"
}

@MainActor
@Observable
final class LauncherViewModel {
    // MARK: - Published State
    var allApps: [AppItem] = []
    var viewMode: AppViewMode = .folders
    var selectedListCategory: AppCategory? = nil
    var isLoading: Bool = true
    var appPendingUninstall: AppItem? = nil
    var uninstallError: String? = nil
    var onDismiss: (() -> Void)?
    var onShowSettings: (() -> Void)?

    // MARK: - Child ViewModels
    let searchViewModel = SearchViewModel()
    let categoryViewModel = CategoryViewModel()
    let pinnedAppsViewModel: PinnedAppsViewModel

    // MARK: - Services (injected)
    private let appScanner: AppScanner
    private let classifier: CategoryClassifier
    private let launchService: LaunchService
    private let dockService: DockService
    private let uninstallService: UninstallService
    private let appStateTracker: AppStateTracker
    private let modelContext: ModelContext
    var badgeService: BadgeService?

    init(appScanner: AppScanner, classifier: CategoryClassifier, launchService: LaunchService, modelContext: ModelContext) {
        self.appScanner = appScanner
        self.classifier = classifier
        self.launchService = launchService
        self.modelContext = modelContext
        self.dockService = DockService()
        self.uninstallService = UninstallService(modelContext: modelContext)
        self.appStateTracker = AppStateTracker(modelContext: modelContext)
        self.pinnedAppsViewModel = PinnedAppsViewModel(modelContext: modelContext)

        // Load saved category order
        let settings = SettingsHelper.getOrCreate(context: modelContext)
        if !settings.categoryOrder.isEmpty {
            let rawValues = settings.categoryOrder.components(separatedBy: ",")
            categoryViewModel.categoryOrder = rawValues.compactMap { AppCategory(rawValue: $0) }
        }

        // Persist category order on change
        categoryViewModel.onCategoryOrderChanged = { [weak self] order in
            guard let self else { return }
            let s = SettingsHelper.getOrCreate(context: self.modelContext)
            s.categoryOrder = order.map(\.rawValue).joined(separator: ",")
            try? self.modelContext.save()
        }

        searchViewModel.onLaunch = { [weak self] app in
            self?.launchApp(app)
        }
        searchViewModel.onClearFolder = { [weak self] in
            self?.selectedListCategory = nil
            self?.categoryViewModel.collapseCategory()
        }
    }

    var allAppsSorted: [AppItem] {
        let filtered = if let cat = selectedListCategory {
            allApps.filter { $0.category == cat }
        } else {
            allApps.filter { $0.category != .other }
        }
        return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var otherAppsSorted: [AppItem] {
        allApps
            .filter { $0.category == .other }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Actions

    func onAppear() {
        guard isLoading else { return }
        loadApps()
        appScanner.onAppsChanged = { [weak self] _ in
            self?.loadApps()
        }
        appScanner.startMonitoring()
    }

    func launchApp(_ app: AppItem) {
        appStateTracker.recordLaunch(of: app)
        launchService.launch(app)
        // Clear dot state and propagate to all view models
        if app.isNew || app.isUpdated {
            if let index = allApps.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
                allApps[index].isNew = false
                allApps[index].isUpdated = false
            }
            // Update child view models so dots disappear in category/search views
            let grouped = Dictionary(grouping: allApps, by: \.category)
            categoryViewModel.updateCategories(grouped)
            searchViewModel.updateAppList(allApps)
        }
        onDismiss?()
    }

    func pinApp(_ app: AppItem) {
        pinnedAppsViewModel.pinApp(app)
    }

    func unpinApp(_ app: AppItem) {
        pinnedAppsViewModel.unpinApp(app)
    }

    func isAppPinned(_ app: AppItem) -> Bool {
        pinnedAppsViewModel.pinnedBundleIDs.contains(app.bundleIdentifier)
    }

    func moveAppToCategory(_ app: AppItem, category: AppCategory) {
        categoryViewModel.moveApp(app, to: category)
    }

    // MARK: - Dock & Desktop

    func addToDock(_ app: AppItem) {
        _ = dockService.addToDock(app)
    }

    func createDesktopShortcut(_ app: AppItem) {
        guard let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first else { return }
        let aliasURL = desktopURL.appendingPathComponent(app.name)
        try? FileManager.default.createSymbolicLink(at: aliasURL, withDestinationURL: app.url)
    }

    // MARK: - Uninstall

    func canUninstall(_ app: AppItem) -> Bool {
        uninstallService.canUninstall(app)
    }

    func requestUninstall(_ app: AppItem) {
        appPendingUninstall = app
    }

    func confirmUninstall() async {
        guard let app = appPendingUninstall else { return }
        appPendingUninstall = nil

        let result = await uninstallService.uninstall(app)
        switch result {
        case .success:
            allApps.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
            pinnedAppsViewModel.unpinApp(app)
            loadApps()
        case .failure(let error):
            uninstallError = error.localizedDescription
        }
    }

    func cancelUninstall() {
        appPendingUninstall = nil
    }

    func dismissUninstallError() {
        uninstallError = nil
    }

    func refreshApps() {
        loadApps()
    }

    // MARK: - Badge & Dot Helpers

    func badgeCount(for app: AppItem) -> Int {
        badgeService?.badgeCounts[app.bundleIdentifier] ?? 0
    }

    func badgeCount(for category: AppCategory) -> Int {
        let apps = categoryViewModel.appsForCategory(category)
        return apps.reduce(0) { $0 + badgeCount(for: $1) }
    }

    func hasNewOrUpdatedApps(in category: AppCategory) -> Bool {
        categoryViewModel.appsForCategory(category).contains { $0.isNew || $0.isUpdated }
    }

    func newOrUpdatedBundleIDs(in category: AppCategory) -> Set<String> {
        Set(categoryViewModel.appsForCategory(category)
            .filter { $0.isNew || $0.isUpdated }
            .map(\.bundleIdentifier))
    }

    // MARK: - Private

    private func loadApps() {
        let scanned = appScanner.scan()
        let classified = classifier.classify(scanned)
        allApps = appStateTracker.annotate(classified)

        searchViewModel.updateAppList(allApps)
        pinnedAppsViewModel.loadPinnedApps(from: allApps)

        let grouped = Dictionary(grouping: allApps, by: \.category)
        categoryViewModel.updateCategories(grouped)
        isLoading = false
    }
}
