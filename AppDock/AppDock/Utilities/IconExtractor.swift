import AppKit

@MainActor
final class IconExtractor {
    static let shared = IconExtractor()
    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 500
    }

    func icon(for bundleURL: URL, size: CGFloat) -> NSImage {
        let cacheKey = "\(bundleURL.path)_\(Int(size))" as NSString

        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        let icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
        icon.size = NSSize(width: size, height: size)
        cache.setObject(icon, forKey: cacheKey)
        return icon
    }
}
