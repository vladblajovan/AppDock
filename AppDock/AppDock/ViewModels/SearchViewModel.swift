import SwiftUI

enum NavigationDirection {
    case up, down, left, right
}

@MainActor
@Observable
final class SearchViewModel {
    var query: String = "" {
        didSet { search() }
    }
    var results: [FuzzyMatchResult] = []
    var highlightedIndex: Int = 0
    var activeFolder: AppCategory?
    private var folderApps: [AppItem] = []

    var isActive: Bool { !query.isEmpty }
    var onLaunch: ((AppItem) -> Void)?

    private let fuzzyMatcher: FuzzyMatcher
    private var allApps: [AppItem] = []

    init(fuzzyMatcher: FuzzyMatcher = FuzzyMatcher()) {
        self.fuzzyMatcher = fuzzyMatcher
    }

    func updateAppList(_ apps: [AppItem]) {
        allApps = apps
        if isActive { search() }
    }

    func clearSearch() {
        query = ""
        results = []
        highlightedIndex = 0
    }

    func setActiveFolder(_ category: AppCategory?, apps: [AppItem]) {
        activeFolder = category
        folderApps = apps
        if isActive { search() }
    }

    func clearActiveFolder() {
        activeFolder = nil
        folderApps = []
        if isActive { search() }
    }

    func moveHighlight(_ direction: NavigationDirection, columnsPerRow: Int = 6) {
        guard !results.isEmpty else { return }

        switch direction {
        case .right:
            highlightedIndex = min(highlightedIndex + 1, results.count - 1)
        case .left:
            highlightedIndex = max(highlightedIndex - 1, 0)
        case .down:
            let next = highlightedIndex + columnsPerRow
            if next < results.count { highlightedIndex = next }
        case .up:
            let prev = highlightedIndex - columnsPerRow
            if prev >= 0 { highlightedIndex = prev }
        }
    }

    var highlightedApp: AppItem? {
        guard highlightedIndex < results.count else { return nil }
        return results[highlightedIndex].app
    }

    // MARK: - Private

    private func search() {
        if query.isEmpty {
            results = []
            highlightedIndex = 0
            return
        }
        let searchPool = activeFolder != nil ? folderApps : allApps
        results = fuzzyMatcher.match(query: query, in: searchPool)
        highlightedIndex = 0
    }
}
