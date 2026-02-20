import SwiftUI
import SwiftData

@MainActor
@Observable
final class SettingsViewModel {
    var hotkeyKeyCode: Int = -1
    var hotkeyModifiers: Int = 0
    var showSuggestions: Bool = true
    var launchAtLogin: Bool = false
    var useLLMClassification: Bool = true
    var showAppNames: Bool = true
    var currentTheme: AppTheme = .system
    var hasCompletedOnboarding: Bool = false
    var onThemeChanged: ((AppTheme) -> Void)?
    var onHotkeyChanged: ((Int, Int) -> Void)?

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
        self.launchAtLogin = s.launchAtLogin
        self.useLLMClassification = s.useLLMClassification
        self.showAppNames = s.showAppNames
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
        launchAtLogin = value
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

    func setHotkey(keyCode: Int, modifiers: Int) {
        hotkeyKeyCode = keyCode
        hotkeyModifiers = modifiers
        saveSettings()
        onHotkeyChanged?(keyCode, modifiers)
    }
}
