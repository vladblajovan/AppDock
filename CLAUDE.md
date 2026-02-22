# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is an Xcode project (not SPM). Open `AppDock/AppDock.xcodeproj` in Xcode.

```bash
# Build from command line
xcodebuild -project AppDock/AppDock.xcodeproj -scheme "AppDock - Dev" -configuration Debug build

# Run the app
open "$(xcodebuild -project AppDock/AppDock.xcodeproj -scheme 'AppDock - Dev' -showBuildSettings | grep ' BUILT_PRODUCTS_DIR' | sed 's/.*= //')/AppDock - Dev.app"
```

**Local config setup** (required before first build):
```bash
cp AppDock/Config/Local.xcconfig.example AppDock/Config/Local.xcconfig
# Edit Local.xcconfig with your DEVELOPMENT_TEAM and PRODUCT_BUNDLE_IDENTIFIER
```

**No tests exist** — the project has no test targets.

## Architecture

**MVVM with service injection.** This is strictly enforced:
- **Views** never import `Core/`, never call `NSWorkspace`, `FileManager`, or `ModelContext` directly
- **ViewModels** are all `@MainActor @Observable final class` (NOT `ObservableObject`/`@Published`)
- **Core services** are injected into ViewModels via initializers
- `AppDelegate` creates root `LauncherViewModel` with all services injected; child ViewModels are created by the root

### Source Layout (under `AppDock/AppDock/`)

- `AppDockApp.swift` — `@main`, `MenuBarExtra` menu bar app (no `WindowGroup`), `AppDelegate` manages lifecycle
- `Core/` — Services: `AppScanner`, `CategoryClassifier`, `WindowManager`, `HotkeyManager`, `BadgeService`, `LaunchService`, `DockService`, `UninstallService`
- `Core/AppDiscovery/` — 3-file pipeline: `AppScanner` → `AppMetadataParser` → `CategoryClassifier` (5-layer classification)
- `Models/` — `AppItem` (in-memory), `AppCategory` (13-category enum), `UserPreferences.swift` (4 SwiftData models: `AppPreference`, `AppSettings`, `LLMClassificationCache`, `UsageRecord`)
- `ViewModels/` — `LauncherViewModel` (root orchestrator), `SearchViewModel`, `CategoryViewModel`, `PinnedAppsViewModel`, `SettingsViewModel`
- `Views/` — `LauncherView` (main panel, largest file ~27KB), `AppIconView`, `CategoryGridView`, `PinnedAppsRow`, `SearchBarView`, `SettingsView`, etc.
- `Platform/` — `PlatformStyle` (centralized design tokens), `GlassBackgroundView`, `AdaptivePanelConfigurator`
- `Utilities/` — `FuzzyMatcher`, `IconExtractor`

### Key Architectural Decisions

- **Menu bar app**: Uses `.accessory` activation policy — no Dock icon, no main window, only `MenuBarExtra` + floating `NSPanel`
- **NSPanel for launcher**: `KeyablePanel` subclass (`canBecomeKey = true`) for keyboard input. Uses `orderFrontRegardless()` + `makeKey()` instead of `makeKeyAndOrderFront`
- **Settings window**: Standalone `NSWindow` with temporary `.regular` activation policy (SwiftUI `Settings` scene doesn't work with `.accessory` policy)
- **Global hotkey**: Carbon `RegisterEventHotKey` (not CGEvent taps despite what the planning doc says)
- **SwiftData persistence**: All persistent state uses SwiftData. `AppSettings` is a singleton (one row, fetch-or-create pattern via `SettingsHelper.getOrCreate(context:)`)
- **No third-party dependencies**

## Platform Adaptation

Targets **macOS 15.0+** (Sequoia), compiled with **macOS 26 SDK** for Tahoe features:

- **macOS 26**: Liquid Glass via `.glassEffect(.regular, in: RoundedRectangle(...))`, wider corner radii (22pt), `FoundationModels` framework (weak-linked/Optional)
- **macOS 15**: `NSVisualEffectView` with `.hudWindow` material, tighter radii (16pt)
- All visual constants flow through `PlatformStyle` — never hardcode spacing, radii, or fonts
- Gate macOS 26 APIs behind `#available(macOS 26, *)`

## Concurrency & Swift 6

- **Strict concurrency**: `SWIFT_STRICT_CONCURRENCY = Complete`
- All ViewModels are `@MainActor`
- `Sendable` types for cross-isolation data
- `@preconcurrency import AppKit` where needed
- SwiftData `#Predicate` cannot capture external variables — use fetch-all-then-filter pattern

## Known Gotchas

- `ModelContainer` uses default config — named configs caused `fopen` errors
- Panel `hidesOnDeactivate` is `false` (was preventing panel from showing)
- Panel show/hide animations disabled (caused "task name port right" errors with `.accessory` policy)
- `.glassEffect` needs explicit `in: RoundedRectangle(cornerRadius:)` to avoid default capsule shape
- `AccessibilityChecker` uses string literal `"AXTrustedCheckOptionPrompt"` instead of `kAXTrustedCheckOptionPrompt` to avoid Swift 6 concurrency issues
- App runs **unsandboxed** (required for global hotkeys, app scanning, Dock manipulation)
- Hotkey requires user to grant Accessibility permission in System Settings

## Development Status

Phases 1-6 complete (foundation, discovery, UI, search, pinning, drag & drop). Phases 7-9 (usage tracking/suggestions, Foundation Models LLM integration, polish) not started. See `plans/APPDOCK_CLAUDE_CODE_PROMPT.md` for full phase breakdown.
