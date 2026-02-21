import SwiftUI
import SwiftData

struct SettingsView: View {
    var viewModel: SettingsViewModel

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }

            appearanceTab
                .tabItem { Label("Appearance", systemImage: "paintbrush") }

            if viewModel.isLLMAvailable {
                aiTab
                    .tabItem { Label("AI", systemImage: "brain") }
            }
        }
        .frame(width: 450, height: 420)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("Hotkey") {
                HStack {
                    Text("Toggle AppDock:")
                    Spacer()
                    HotkeyRecorderView(
                        keyCode: Binding(
                            get: { viewModel.hotkeyKeyCode },
                            set: { viewModel.setHotkey(keyCode: $0, modifiers: viewModel.hotkeyModifiers) }
                        ),
                        modifiers: Binding(
                            get: { viewModel.hotkeyModifiers },
                            set: { viewModel.setHotkey(keyCode: viewModel.hotkeyKeyCode, modifiers: $0) }
                        )
                    )
                    .frame(width: 140, height: 24)
                }

                if let warning = viewModel.hotkeyWarning {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(warning)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if viewModel.hotkeyConflictSettingsPath != nil {
                        Button("Open Keyboard Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
                        }
                        .controlSize(.small)
                    }
                }
            }

            Section("Behavior") {
                Toggle("Show Suggestions", isOn: Binding(
                    get: { viewModel.showSuggestions },
                    set: { viewModel.setShowSuggestions($0) }
                ))
                .disabled(true)
                Text("Coming soon")
                    .font(.caption)
                    .foregroundStyle(.orange)

                Toggle("Launch at Login", isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { viewModel.setLaunchAtLogin($0) }
                ))

                Toggle("Hide when clicking outside", isOn: Binding(
                    get: { viewModel.hideOnFocusLoss },
                    set: { viewModel.setHideOnFocusLoss($0) }
                ))
            }

            Section("Notifications") {
                Toggle("Show notification badges", isOn: Binding(
                    get: { viewModel.showNotificationBadges },
                    set: { viewModel.setShowNotificationBadges($0) }
                ))

                if viewModel.showNotificationBadges, let badge = viewModel.badgeService, !badge.isAccessibilityGranted {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("Accessibility permission required")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                        .controlSize(.small)
                    }
                }

                Text("Shows notification badge counts from apps in your Dock. Requires Accessibility permission to read badge information.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Categories") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Reset Category Overrides")
                        Text("Revert all manually assigned app categories back to their defaults.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Reset") {
                        viewModel.resetCategoryOverrides()
                    }
                    .disabled(!viewModel.hasCategoryOverrides)
                }
            }

            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.appVersionString)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Appearance Tab

    private var appearanceTab: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: Binding(
                    get: { viewModel.currentTheme },
                    set: { viewModel.setTheme($0) }
                )) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Display") {
                Toggle("Show App Names", isOn: Binding(
                    get: { viewModel.showAppNames },
                    set: { viewModel.setShowAppNames($0) }
                ))

                Toggle("Show Pinned App Names", isOn: Binding(
                    get: { viewModel.showPinnedAppNames },
                    set: { viewModel.setShowPinnedAppNames($0) }
                ))
            }

            Section {
                Text("On macOS 26 (Tahoe), AppDock uses Liquid Glass materials that automatically adapt to your desktop wallpaper.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - AI Tab

    private var aiTab: some View {
        Form {
            Section("On-Device Classification") {
                Toggle("Use AI for app categorization", isOn: .constant(false))
                .disabled(true)
                Text("Coming soon")
                    .font(.caption)
                    .foregroundStyle(.orange)

                Text("Uses Apple's on-device language model to classify apps that can't be categorized by metadata alone. No data leaves your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
