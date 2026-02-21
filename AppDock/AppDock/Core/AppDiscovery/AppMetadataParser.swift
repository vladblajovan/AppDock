import Foundation
import CoreServices

struct AppMetadata: Sendable {
    let displayName: String
    let bundleIdentifier: String
    let appStoreCategory: String?
    let isUIElement: Bool
    let isBackgroundOnly: Bool
    let version: String?
}

struct AppMetadataParser {
    static func parse(bundleURL: URL) -> AppMetadata? {
        let infoPlistURL = bundleURL.appendingPathComponent("Contents/Info.plist")

        guard let data = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }

        let displayName = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? bundleURL.deletingPathExtension().lastPathComponent

        guard let bundleIdentifier = plist["CFBundleIdentifier"] as? String else {
            return nil
        }

        // Try Info.plist first, then fall back to Spotlight metadata
        let appStoreCategory = (plist["LSApplicationCategoryType"] as? String)
            ?? spotlightCategory(for: bundleURL)

        let isUIElement = (plist["LSUIElement"] as? Bool) ?? (plist["LSUIElement"] as? Int == 1)
        let isBackgroundOnly = (plist["LSBackgroundOnly"] as? Bool) ?? (plist["LSBackgroundOnly"] as? Int == 1)
        let version = plist["CFBundleShortVersionString"] as? String

        return AppMetadata(
            displayName: displayName,
            bundleIdentifier: bundleIdentifier,
            appStoreCategory: appStoreCategory,
            isUIElement: isUIElement,
            isBackgroundOnly: isBackgroundOnly,
            version: version
        )
    }

    private static func spotlightCategory(for bundleURL: URL) -> String? {
        guard let mdItem = MDItemCreateWithURL(kCFAllocatorDefault, bundleURL as CFURL) else {
            return nil
        }
        // Prefer the UTI string (e.g. "public.app-category.developer-tools")
        if let categoryType = MDItemCopyAttribute(mdItem, "kMDItemAppStoreCategoryType" as CFString) as? String {
            return categoryType
        }
        // Fall back to human-readable name and convert to UTI format
        if let categoryName = MDItemCopyAttribute(mdItem, "kMDItemAppStoreCategory" as CFString) as? String {
            let slug = categoryName.lowercased()
                .replacingOccurrences(of: " & ", with: "-")
                .replacingOccurrences(of: " ", with: "-")
            return "public.app-category.\(slug)"
        }
        return nil
    }
}
