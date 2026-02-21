import SwiftUI
import SwiftData
import ServiceManagement

@MainActor
@Observable
final class SettingsViewModel {
    var hotkeyKeyCode: Int = -1
    var hotkeyModifiers: Int = 0
    var showSuggestions: Bool = true
    var launchAtLogin: Bool = false
    var useLLMClassification: Bool = true
    var showAppNames: Bool = true
    var showPinnedAppNames: Bool = false
    var hideOnFocusLoss: Bool = true
    var showNotificationBadges: Bool = false
    var currentTheme: AppTheme = .system
    var hasCompletedOnboarding: Bool = false
    var onThemeChanged: ((AppTheme) -> Void)?
    var onHotkeyChanged: ((Int, Int) -> Void)?
    var onHideOnFocusLossChanged: ((Bool) -> Void)?
    var onShowNotificationBadgesChanged: ((Bool) -> Void)?
    var onCategoryOverridesReset: (() -> Void)?
    var badgeService: BadgeService?
    var hotkeyWarning: String? = nil
    var hotkeyConflictSettingsPath: String? = nil

    var isLLMAvailable: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    private let modelContext: ModelContext
    private var settings: AppSettings?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadSettings()
    }

    func loadSettings() {
        let s = SettingsHelper.getOrCreate(context: modelContext)
        self.settings = s
        self.hotkeyKeyCode = s.hotkeyKeyCode
        self.hotkeyModifiers = s.hotkeyModifiers
        self.showSuggestions = s.showSuggestions
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        self.useLLMClassification = s.useLLMClassification
        self.showAppNames = s.showAppNames
        self.showPinnedAppNames = s.showPinnedAppNames
        self.hideOnFocusLoss = s.hideOnFocusLoss
        self.showNotificationBadges = s.showNotificationBadges
        self.currentTheme = s.appTheme
        self.hasCompletedOnboarding = s.hasCompletedOnboarding
    }

    func saveSettings() {
        guard let settings else { return }
        settings.hotkeyKeyCode = hotkeyKeyCode
        settings.hotkeyModifiers = hotkeyModifiers
        settings.showSuggestions = showSuggestions
        settings.launchAtLogin = launchAtLogin
        settings.useLLMClassification = useLLMClassification
        settings.showAppNames = showAppNames
        settings.showPinnedAppNames = showPinnedAppNames
        settings.hideOnFocusLoss = hideOnFocusLoss
        settings.showNotificationBadges = showNotificationBadges
        settings.theme = currentTheme.rawValue
        settings.hasCompletedOnboarding = hasCompletedOnboarding
        try? modelContext.save()
    }

    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        saveSettings()
        onThemeChanged?(theme)
    }

    func setShowSuggestions(_ value: Bool) {
        showSuggestions = value
        saveSettings()
    }

    func setLaunchAtLogin(_ value: Bool) {
        do {
            if value {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = value
        } catch {
            // Registration failed — revert the toggle
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        saveSettings()
    }

    func setUseLLMClassification(_ value: Bool) {
        useLLMClassification = value
        saveSettings()
    }

    func setShowAppNames(_ value: Bool) {
        showAppNames = value
        UserDefaults.standard.set(value, forKey: "showAppNames")
        saveSettings()
    }

    func setShowPinnedAppNames(_ value: Bool) {
        showPinnedAppNames = value
        UserDefaults.standard.set(value, forKey: "showPinnedAppNames")
        saveSettings()
    }

    func setShowNotificationBadges(_ value: Bool) {
        if value {
            badgeService?.requestAccessibilityPermissionIfNeeded()
        }
        showNotificationBadges = value
        saveSettings()
        onShowNotificationBadgesChanged?(value)
    }

    func setHideOnFocusLoss(_ value: Bool) {
        hideOnFocusLoss = value
        saveSettings()
        onHideOnFocusLossChanged?(value)
    }

    func resetCategoryOverrides() {
        let descriptor = FetchDescriptor<AppPreference>()
        guard let allPrefs = try? modelContext.fetch(descriptor) else { return }
        for pref in allPrefs where pref.categoryOverride != nil {
            pref.categoryOverride = nil
        }
        try? modelContext.save()
        onCategoryOverridesReset?()
    }

    var hasCategoryOverrides: Bool {
        let descriptor = FetchDescriptor<AppPreference>()
        guard let allPrefs = try? modelContext.fetch(descriptor) else { return false }
        return allPrefs.contains { $0.categoryOverride != nil }
    }

    func setHotkey(keyCode: Int, modifiers: Int) {
        hotkeyKeyCode = keyCode
        hotkeyModifiers = modifiers

        if let conflict = HotkeyConflictChecker.check(keyCode: keyCode, modifiers: modifiers) {
            if conflict.registrationFailed {
                if let path = conflict.settingsPath {
                    hotkeyWarning = "This shortcut is used by \(conflict.displayName). Disable it in System Settings > \(path) to use it here."
                } else {
                    hotkeyWarning = "This shortcut could not be registered — it is in use by \(conflict.displayName)."
                }
            } else {
                if let path = conflict.settingsPath {
                    hotkeyWarning = "This shortcut may conflict with \(conflict.displayName). If it doesn't work, disable it in System Settings > \(path)."
                } else {
                    hotkeyWarning = "This shortcut may conflict with \(conflict.displayName)."
                }
            }
            hotkeyConflictSettingsPath = conflict.settingsPath
        } else {
            hotkeyWarning = nil
            hotkeyConflictSettingsPath = nil
        }

        saveSettings()
        onHotkeyChanged?(keyCode, modifiers)
    }
}
