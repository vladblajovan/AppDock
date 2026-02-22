import SwiftUI
import SwiftData

enum AppViewMode: String, CaseIterable {
    case folders = "Folders"
    case list = "List"
}

enum BrowseSection {
    case categories
    case pinned
    case main
}

@MainActor
@Observable
final class LauncherViewModel {
    // MARK: - Published State
    var allApps: [AppItem] = [] {
        didSet { invalidateSortedCaches() }
    }
    var viewMode: AppViewMode = .folders {
        didSet {
            guard didFinishInit else { return }
            let s = SettingsHelper.getOrCreate(context: modelContext)
            s.viewMode = viewMode.rawValue
            try? modelContext.save()
        }
    }
    var selectedListCategory: AppCategory? = nil {
        didSet { invalidateSortedCaches() }
    }
    var isLoading: Bool = true
    var appPendingUninstall: AppItem? = nil
    var uninstallError: String? = nil
    var onDismiss: (() -> Void)?
    var onShowSettings: (() -> Void)?

    // MARK: - Browse Keyboard Navigation
    var highlightedSection: BrowseSection = .main
    var highlightedItemIndex: Int? = nil
    var isKeyboardNavigating: Bool = false

    // MARK: - Child ViewModels
    let searchViewModel = SearchViewModel()
    let categoryViewModel = CategoryViewModel()
    let pinnedAppsViewModel: PinnedAppsViewModel

    private var didFinishInit = false

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

        // Load saved view mode and category order
        let settings = SettingsHelper.getOrCreate(context: modelContext)
        if let savedMode = AppViewMode(rawValue: settings.viewMode) {
            self.viewMode = savedMode
        }
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

        didFinishInit = true
    }

    // Cached sorted lists — invalidated when allApps or selectedListCategory changes
    private var cachedAllAppsSorted: [AppItem]?
    private var cachedAllAppsSortedCategory: AppCategory?? = .some(nil) // sentinel to force first computation
    private var cachedOtherAppsSorted: [AppItem]?

    var allAppsSorted: [AppItem] {
        let cat = selectedListCategory
        if let cached = cachedAllAppsSorted, cachedAllAppsSortedCategory == .some(cat) {
            return cached
        }
        let filtered = if let cat {
            allApps.filter { $0.category == cat }
        } else {
            allApps.filter { $0.category != .other }
        }
        let sorted = filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        cachedAllAppsSorted = sorted
        cachedAllAppsSortedCategory = .some(cat)
        return sorted
    }

    var otherAppsSorted: [AppItem] {
        if let cached = cachedOtherAppsSorted { return cached }
        let sorted = allApps
            .filter { $0.category == .other }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        cachedOtherAppsSorted = sorted
        return sorted
    }

    private func invalidateSortedCaches() {
        cachedAllAppsSorted = nil
        cachedAllAppsSortedCategory = .some(nil)
        cachedOtherAppsSorted = nil
    }

    var currentBrowseItemCount: Int {
        if viewMode == .folders {
            if categoryViewModel.expandedCategory != nil {
                return categoryViewModel.appsForCategory(categoryViewModel.expandedCategory!).count
            } else {
                return categoryViewModel.nonEmptyCategories.count
            }
        } else {
            // List mode
            let mainCount = allAppsSorted.count
            if selectedListCategory == nil {
                return mainCount + otherAppsSorted.count
            }
            return mainCount
        }
    }

    /// Whether the pinned row is visible in the current state.
    var isPinnedRowVisible: Bool {
        !pinnedAppsViewModel.isEmpty
            && categoryViewModel.expandedCategory == nil
            && !(viewMode == .list && selectedListCategory != nil)
    }

    /// Whether the category carousel is visible (list mode, no category selected, no expanded folder).
    var isCategoryCarouselVisible: Bool {
        viewMode == .list
            && categoryViewModel.expandedCategory == nil
    }

    /// Categories shown in the carousel (excludes "Other").
    var carouselCategories: [AppCategory] {
        categoryViewModel.nonEmptyCategories.filter { $0 != .other }
    }

    func moveHighlightInBrowse(_ direction: NavigationDirection, columnsPerRow: Int, pinnedColumnsPerRow: Int) {
        guard let current = highlightedItemIndex else {
            // First press: activate highlight at top-left of the topmost visible section
            if isCategoryCarouselVisible {
                highlightedSection = .categories
                highlightedItemIndex = 0
            } else if isPinnedRowVisible {
                highlightedSection = .pinned
                highlightedItemIndex = 0
            } else {
                highlightedSection = .main
                highlightedItemIndex = 0
            }
            return
        }

        let count: Int
        switch highlightedSection {
        case .categories:
            count = carouselCategories.count
        case .pinned:
            count = pinnedAppsViewModel.pinnedApps.count
        case .main:
            count = currentBrowseItemCount
        }

        switch direction {
        case .right:
            highlightedItemIndex = min(current + 1, count - 1)
        case .left:
            highlightedItemIndex = max(current - 1, 0)
        case .down:
            if highlightedSection == .categories {
                if isPinnedRowVisible {
                    highlightedSection = .pinned
                    highlightedItemIndex = 0
                } else {
                    highlightedSection = .main
                    highlightedItemIndex = 0
                }
            } else if highlightedSection == .pinned {
                highlightedSection = .main
                highlightedItemIndex = 0
            } else {
                let next = current + columnsPerRow
                if next < count { highlightedItemIndex = next }
            }
        case .up:
            if highlightedSection == .main {
                let prev = current - columnsPerRow
                if prev >= 0 {
                    highlightedItemIndex = prev
                } else if isPinnedRowVisible {
                    highlightedSection = .pinned
                    highlightedItemIndex = 0
                } else if isCategoryCarouselVisible {
                    highlightedSection = .categories
                    highlightedItemIndex = 0
                }
            } else if highlightedSection == .pinned {
                let prev = current - pinnedColumnsPerRow
                if prev >= 0 {
                    highlightedItemIndex = prev
                } else if isCategoryCarouselVisible {
                    highlightedSection = .categories
                    highlightedItemIndex = 0
                }
            } else {
                // categories — no row above
                highlightedItemIndex = max(current - 1, 0)
            }
        }
    }

    func activateHighlightedItem() {
        guard let index = highlightedItemIndex else { return }

        if highlightedSection == .categories {
            let cats = carouselCategories
            guard index < cats.count else { return }
            let category = cats[index]
            if selectedListCategory == category {
                selectedListCategory = nil
                searchViewModel.clearActiveFolder()
            } else {
                selectedListCategory = category
                let apps = categoryViewModel.appsForCategory(category)
                searchViewModel.setActiveFolder(category, apps: apps)
            }
            highlightedSection = .main
            highlightedItemIndex = 0
            return
        }

        if highlightedSection == .pinned {
            let pinned = pinnedAppsViewModel.pinnedApps
            guard index < pinned.count else { return }
            launchApp(pinned[index])
            return
        }

        if viewMode == .folders {
            if let expanded = categoryViewModel.expandedCategory {
                let apps = categoryViewModel.appsForCategory(expanded)
                guard index < apps.count else { return }
                launchApp(apps[index])
            } else {
                let categories = categoryViewModel.nonEmptyCategories
                guard index < categories.count else { return }
                let category = categories[index]
                categoryViewModel.expandCategory(category)
                let apps = categoryViewModel.appsForCategory(category)
                searchViewModel.setActiveFolder(category, apps: apps)
                highlightedItemIndex = nil
            }
        } else {
            // List mode: main apps then other apps
            let mainApps = allAppsSorted
            if index < mainApps.count {
                launchApp(mainApps[index])
            } else if selectedListCategory == nil {
                let otherIndex = index - mainApps.count
                let others = otherAppsSorted
                guard otherIndex < others.count else { return }
                launchApp(others[otherIndex])
            }
        }
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

    func handleMouseBack() {
        if searchViewModel.isActive {
            searchViewModel.clearSearch()
        } else if categoryViewModel.expandedCategory != nil {
            categoryViewModel.collapseCategory()
            searchViewModel.clearActiveFolder()
        } else if selectedListCategory != nil {
            selectedListCategory = nil
            searchViewModel.clearActiveFolder()
        }
        highlightedItemIndex = nil
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
        // Sync the category change back into allApps so list mode reflects it immediately.
        // Replace the whole array to ensure @Observable triggers a view update.
        var updated = allApps
        if let index = updated.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            updated[index].category = category
        }
        allApps = updated
        searchViewModel.updateAppList(allApps)

        // Persist the category override so it survives app restarts and rescans
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
        pref.categoryOverride = category.rawValue
        try? modelContext.save()
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

        // Clear stale icons (app updates may change icons) and pre-warm fresh ones
        IconExtractor.shared.clearCache()
        IconExtractor.shared.preWarmCache(apps: allApps, sizes: [PlatformStyle.appIconSize, 56])
    }
}
