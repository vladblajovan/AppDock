import Foundation
import SwiftData

@Model
final class UsageRecord {
    var bundleIdentifier: String
    var timestamp: Date
    var hourOfDay: Int
    var dayOfWeek: Int

    init(bundleIdentifier: String) {
        let now = Date()
        let calendar = Calendar.current
        self.bundleIdentifier = bundleIdentifier
        self.timestamp = now
        self.hourOfDay = calendar.component(.hour, from: now)
        self.dayOfWeek = calendar.component(.weekday, from: now)
    }
}
