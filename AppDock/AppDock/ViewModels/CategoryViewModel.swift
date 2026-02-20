import SwiftUI

@MainActor
@Observable
final class CategoryViewModel {
    var categorizedApps: [AppCategory: [AppItem]] = [:] {
        didSet { invalidateCache() }
    }
    var expandedCategory: AppCategory? = nil

    // Cached sorted apps and preview apps per category
    private var sortedAppsCache: [AppCategory: [AppItem]] = [:]
    private var previewAppsCache: [AppCategory: [AppItem]] = [:]
    private var nonEmptyCategoriesCache: [AppCategory]?

    var nonEmptyCategories: [AppCategory] {
        if let cached = nonEmptyCategoriesCache { return cached }
        let result = AppCategory.allCases.filter { categorizedApps[$0]?.isEmpty == false }
        nonEmptyCategoriesCache = result
        return result
    }

    func updateCategories(_ apps: [AppCategory: [AppItem]]) {
        categorizedApps = apps
    }

    func expandCategory(_ category: AppCategory) {
        expandedCategory = category
    }

    func collapseCategory() {
        expandedCategory = nil
    }

    func appsForCategory(_ category: AppCategory) -> [AppItem] {
        if let cached = sortedAppsCache[category] { return cached }
        let sorted = (categorizedApps[category] ?? []).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        sortedAppsCache[category] = sorted
        return sorted
    }

    func previewApps(for category: AppCategory) -> [AppItem] {
        if let cached = previewAppsCache[category] { return cached }
        let preview = Array(appsForCategory(category).prefix(9))
        previewAppsCache[category] = preview
        return preview
    }

    func moveApp(_ app: AppItem, to newCategory: AppCategory) {
        // Remove from old category
        for (cat, apps) in categorizedApps {
            if let index = apps.firstIndex(of: app) {
                categorizedApps[cat]?.remove(at: index)
                break
            }
        }
        // Add to new category
        var updated = app
        updated.category = newCategory
        categorizedApps[newCategory, default: []].append(updated)
    }

    private func invalidateCache() {
        sortedAppsCache.removeAll()
        previewAppsCache.removeAll()
        nonEmptyCategoriesCache = nil
    }
}
