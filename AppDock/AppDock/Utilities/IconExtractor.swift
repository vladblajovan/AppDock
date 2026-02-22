import AppKit

@MainActor
final class IconExtractor {
    static let shared = IconExtractor()
    private let cache = NSCache<NSString, NSImage>()

    private static let calendarBundleID = "com.apple.iCal"

    private init() {
        cache.countLimit = 500
    }

    /// Pre-warm the icon cache for a batch of apps on a background thread.
    /// Icons are extracted off the main thread and inserted into the cache,
    /// so scrolling never hits a cache miss.
    func preWarmCache(apps: [AppItem], sizes: [CGFloat]) {
        struct IconJob: Sendable {
            let path: String
            let bundleIdentifier: String
            let url: URL
        }
        let jobs = apps.map { IconJob(path: $0.url.path, bundleIdentifier: $0.bundleIdentifier, url: $0.url) }
        let calendarID = Self.calendarBundleID

        // Do the expensive NSWorkspace.icon(forFile:) calls on a background thread,
        // then batch-insert results back into the main-actor cache.
        Task.detached(priority: .userInitiated) {
            let today = Calendar.current.component(.day, from: Date())
            var results: [(NSString, NSImage)] = []
            var calendarJobs: [(URL, CGFloat, NSString)] = []

            for job in jobs {
                for size in sizes {
                    let isCalendar = job.bundleIdentifier == calendarID
                    let key = (isCalendar
                        ? "\(job.path)_\(Int(size))_day\(today)"
                        : "\(job.path)_\(Int(size))") as NSString

                    if isCalendar {
                        calendarJobs.append((job.url, size, key))
                    } else {
                        let icon = NSWorkspace.shared.icon(forFile: job.path)
                        icon.size = NSSize(width: size, height: size)
                        results.append((key, icon))
                    }
                }
            }

            // Insert extracted icons into the cache on main actor.
            // Use nonisolated(unsafe) to transfer the non-Sendable NSImage array across
            // the isolation boundary. This is safe because the detached task is done
            // mutating these values and ownership transfers to the main actor.
            nonisolated(unsafe) let batch = results
            nonisolated(unsafe) let calJobs = calendarJobs
            await MainActor.run {
                let extractor = IconExtractor.shared
                for (key, image) in batch {
                    if extractor.cache.object(forKey: key) == nil {
                        extractor.cache.setObject(image, forKey: key)
                    }
                }
                // Calendar icons use lockFocus which requires main thread
                for (url, size, key) in calJobs {
                    if extractor.cache.object(forKey: key) == nil {
                        let icon = extractor.calendarIcon(bundleURL: url, size: size)
                        extractor.cache.setObject(icon, forKey: key)
                    }
                }
            }
        }
    }

    func icon(for bundleURL: URL, size: CGFloat, bundleIdentifier: String? = nil) -> NSImage {
        let today = Calendar.current.component(.day, from: Date())
        let isCalendar = bundleIdentifier == Self.calendarBundleID
        let cacheKey = (isCalendar
            ? "\(bundleURL.path)_\(Int(size))_day\(today)"
            : "\(bundleURL.path)_\(Int(size))") as NSString

        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        let icon: NSImage
        if isCalendar {
            icon = calendarIcon(bundleURL: bundleURL, size: size)
        } else {
            icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
            icon.size = NSSize(width: size, height: size)
        }

        cache.setObject(icon, forKey: cacheKey)
        return icon
    }

    private func calendarIcon(bundleURL: URL, size: CGFloat) -> NSImage {
        let result = NSImage(size: NSSize(width: size, height: size))

        let now = Date()
        let day = Calendar.current.component(.day, from: now)

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEE"
        let weekday = weekdayFormatter.string(from: now)

        result.lockFocus()

        // Inset to match macOS icon padding (icons have ~10% transparent margin)
        let inset = size * 0.1
        let iconRect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
        let cornerRadius = iconRect.width * 0.265
        let bgPath = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)

        // Gradient background: slightly lighter at top, darker at bottom
        NSGraphicsContext.saveGraphicsState()
        bgPath.addClip()
        let bgGradient = NSGradient(colors: [
            NSColor(white: 0.16, alpha: 1.0),  // top
            NSColor(white: 0.08, alpha: 1.0)   // bottom
        ])
        bgGradient?.draw(in: iconRect, angle: 90)
        NSGraphicsContext.restoreGraphicsState()

        // Border stroke
        let borderPath = NSBezierPath(roundedRect: iconRect.insetBy(dx: 0.75, dy: 0.75), xRadius: cornerRadius, yRadius: cornerRadius)
        borderPath.lineWidth = 1.5
        NSColor(white: 1.0, alpha: 0.15).setStroke()
        borderPath.stroke()

        // Draw weekday abbreviation (e.g. "Sat") in red near the top
        let iconSize = iconRect.width
        let weekdayAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: iconSize * 0.18, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)
        ]
        let weekdayStr = weekday as NSString
        let weekdaySize = weekdayStr.size(withAttributes: weekdayAttrs)
        let weekdayOrigin = NSPoint(
            x: iconRect.midX - weekdaySize.width / 2,
            y: iconRect.minY + iconSize * 0.6
        )
        weekdayStr.draw(at: weekdayOrigin, withAttributes: weekdayAttrs)

        // Draw day number large and centered
        let dayAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: iconSize * 0.47, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let dayStr = "\(day)" as NSString
        let daySize = dayStr.size(withAttributes: dayAttrs)
        let dayOrigin = NSPoint(
            x: iconRect.midX - daySize.width / 2,
            y: iconRect.minY + iconSize * 0.1
        )
        dayStr.draw(at: dayOrigin, withAttributes: dayAttrs)

        result.unlockFocus()
        return result
    }
}
