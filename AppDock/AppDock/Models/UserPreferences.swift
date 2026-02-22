import Foundation
import SwiftData

@Model
final class AppPreference {
    @Attribute(.unique) var bundleIdentifier: String
    var isPinned: Bool = false
    var pinOrder: Int = 0
    var categoryOverride: String?
    var isHidden: Bool = false
    var lastKnownVersion: String?
    var isNewApp: Bool = false
    var isUpdatedApp: Bool = false

    init(bundleIdentifier: String) {
        self.bundleIdentifier = bundleIdentifier
    }
}

@Model
final class LLMClassificationCache {
    @Attribute(.unique) var bundleIdentifier: String
    var classifiedCategory: String
    var classifiedAt: Date
    var modelVersion: String

    init(bundleIdentifier: String, category: AppCategory, modelVersion: String) {
        self.bundleIdentifier = bundleIdentifier
        self.classifiedCategory = category.rawValue
        self.classifiedAt = Date()
        self.modelVersion = modelVersion
    }
}

@Model
final class AppSettings {
    var hotkeyKeyCode: Int = -1
    var hotkeyModifiers: Int = 0
    var showSuggestions: Bool = false
    var maxPinnedApps: Int = 12
    var maxSuggestions: Int = 8
    var launchAtLogin: Bool = false
    var useLLMClassification: Bool = true
    var theme: String = "System"
    var showAppNames: Bool = true
    var showPinnedAppNames: Bool = false
    var hasCompletedOnboarding: Bool = false
    var hideOnFocusLoss: Bool = true
    var lastPanelPositionX: Double?
    var lastPanelPositionY: Double?
    var lastPanelHeight: Double?
    var hasPerformedInitialScan: Bool = false
    var showNotificationBadges: Bool = true
    var categoryOrder: String = ""
    var viewMode: String = "Folders"

    init() {}

    var appTheme: AppTheme {
        get { AppTheme(rawValue: theme) ?? .system }
        set { theme = newValue.rawValue }
    }
}
