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
        .frame(width: 450, height: 300)
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
            }

            Section("Behavior") {
                Toggle("Show Suggestions", isOn: Binding(
                    get: { viewModel.showSuggestions },
                    set: { viewModel.setShowSuggestions($0) }
                ))

                Toggle("Launch at Login", isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { viewModel.setLaunchAtLogin($0) }
                ))
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
                Toggle("Use AI for app categorization", isOn: Binding(
                    get: { viewModel.useLLMClassification },
                    set: { viewModel.setUseLLMClassification($0) }
                ))

                Text("Uses Apple's on-device language model to classify apps that can't be categorized by metadata alone. No data leaves your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
