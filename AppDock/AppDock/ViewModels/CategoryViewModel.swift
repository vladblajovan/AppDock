import SwiftUI

@MainActor
@Observable
final class CategoryViewModel {
    var categorizedApps: [AppCategory: [AppItem]] = [:] {
        didSet { invalidateCache() }
    }
    var expandedCategory: AppCategory? = nil

    /// Custom category ordering. Empty = default allCases order.
    var categoryOrder: [AppCategory] = [] {
        didSet { invalidateCache() }
    }

    /// Callback fired when the user reorders categories via drag-and-drop.
    var onCategoryOrderChanged: (([AppCategory]) -> Void)?

    // Cached sorted apps and preview apps per category
    private var sortedAppsCache: [AppCategory: [AppItem]] = [:]
    private var previewAppsCache: [AppCategory: [AppItem]] = [:]
    private var nonEmptyCategoriesCache: [AppCategory]?

    var nonEmptyCategories: [AppCategory] {
        if let cached = nonEmptyCategoriesCache { return cached }
        let order = categoryOrder.isEmpty ? Array(AppCategory.allCases) : categoryOrder
        let nonEmpty = order.filter { categorizedApps[$0]?.isEmpty == false }
        // Append any new categories not yet in the saved order
        let remaining = AppCategory.allCases.filter { cat in
            categorizedApps[cat]?.isEmpty == false && !nonEmpty.contains(cat)
        }
        let result = nonEmpty + remaining
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

    func moveCategory(from source: IndexSet, to destination: Int) {
        var current = nonEmptyCategories
        current.move(fromOffsets: source, toOffset: destination)
        categoryOrder = current
        onCategoryOrderChanged?(current)
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
