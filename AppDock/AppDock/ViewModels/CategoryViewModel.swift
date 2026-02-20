import SwiftUI

@MainActor
@Observable
final class CategoryViewModel {
    var categorizedApps: [AppCategory: [AppItem]] = [:]
    var expandedCategory: AppCategory? = nil

    var nonEmptyCategories: [AppCategory] {
        AppCategory.allCases.filter { categorizedApps[$0]?.isEmpty == false }
    }

    func updateCategories(_ apps: [AppCategory: [AppItem]]) {
        categorizedApps = apps
    }

    func expandCategory(_ category: AppCategory) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            expandedCategory = category
        }
    }

    func collapseCategory() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            expandedCategory = nil
        }
    }

    func appsForCategory(_ category: AppCategory) -> [AppItem] {
        (categorizedApps[category] ?? []).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func previewApps(for category: AppCategory) -> [AppItem] {
        Array(appsForCategory(category).prefix(9))
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
}
