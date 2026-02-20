import AppKit

struct AppItem: Identifiable, Hashable, Sendable {
    let id: String  // bundleIdentifier
    let name: String
    let bundleIdentifier: String
    let url: URL
    let appStoreCategory: String?
    var category: AppCategory
    let isSystemApp: Bool

    var bundleIdentifierPrefix: String {
        let components = bundleIdentifier.split(separator: ".")
        if components.count >= 2 {
            return components.prefix(2).joined(separator: ".")
        }
        return bundleIdentifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }

    static func == (lhs: AppItem, rhs: AppItem) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}
