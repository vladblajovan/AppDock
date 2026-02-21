# AppDock

A modern macOS menu bar app launcher with intelligent categorization, fuzzy search, and Liquid Glass support.

![macOS](https://img.shields.io/badge/macOS-15.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Declarative_UI-green)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

## What is AppDock?

AppDock lives in your menu bar and gives you instant access to all your apps — organized by category, searchable with fuzzy matching, and accessible via a global hotkey. Think of it as a smarter, more visual alternative to Spotlight for launching apps.

## Features

### Intelligent App Discovery
- Automatically scans all standard app directories
- Real-time monitoring — new installs appear instantly
- Extracts categories from App Store metadata and Spotlight index
- Multi-layer classification: bundle metadata, 200+ known app mappings, name-based heuristics, and optional on-device LLM (macOS 26)

### Dual View Modes
- **Folders** — Apps grouped into color-coded category folders with 3×3 icon previews. Tap to expand.
- **List** — Alphabetical grid with a category carousel for quick filtering.
- Drag-and-drop category reordering in the carousel, persisted across launches

### Powerful Search
- Fuzzy matching with typo tolerance
- Abbreviation support (e.g., "vsc" finds Visual Studio Code)
- Context-aware placeholders — shows the active category name when filtering
- Category-scoped search when a folder or filter is active
- Full keyboard navigation with arrow keys

### Pinned Apps
- Pin your favorites to a dedicated row at the top
- Drag to reorder
- Persistent across sessions

### Notification Badges & App State
- Badge counts from running apps displayed on category tiles and app icons
- New and recently updated apps highlighted with indicator dots
- Badge polling toggle in Settings

### Global Hotkey
- Configure any key combination to toggle AppDock
- Recorder UI in Settings — just press your preferred shortcut
- Displayed in the menu bar and search bar
- Auto-hide panel on app launch

### Deep macOS Integration
- Add apps to the Dock
- Create desktop shortcuts
- Uninstall apps (move to Trash)
- Reassign apps to different categories
- Mouse back button navigation support

### Adaptive UI
- **macOS 26 (Tahoe):** Liquid Glass materials that sample your wallpaper in real-time
- **macOS 15 (Sequoia):** Frosted glass HUD-style panel
- System, Light, and Dark theme options
- Resizable panel with persisted dimensions
- Draggable floating window

## Architecture

Clean MVVM with service injection:

```
AppDockApp (entry point)
├── Views/           SwiftUI components
├── ViewModels/      @Observable state management
├── Models/          SwiftData models + domain types
├── Core/            Services (scanning, hotkeys, window management)
├── Platform/        OS-adaptive styling & effects
└── Utilities/       Fuzzy matching, icon extraction
```

**Key technologies:** SwiftUI, SwiftData, AppKit (NSPanel, NSVisualEffectView), Carbon (RegisterEventHotKey), CoreServices (Spotlight MDItem)

## Requirements

- macOS 15.0 (Sequoia) or later
- Xcode 16+ to build from source

## Getting Started

1. Clone the repository
   ```bash
   git clone https://github.com/vladblajovan/AppDock.git
   ```
2. Set up your local build configuration:
   ```bash
   cp AppDock/Config/Local.xcconfig.example AppDock/Config/Local.xcconfig
   ```
3. Edit `AppDock/Config/Local.xcconfig` with your Apple Developer Team ID and bundle identifier:
   ```
   DEVELOPMENT_TEAM = YOUR_TEAM_ID
   PRODUCT_BUNDLE_IDENTIFIER = com.yourname.appdock
   ```
   You can find your Team ID in [Apple Developer account](https://developer.apple.com/account) under Membership Details, or in Xcode under Settings > Accounts.
4. Open `AppDock/AppDock.xcodeproj` in Xcode
5. Build and run (Cmd+R)
6. Set a global hotkey in Settings to toggle AppDock from anywhere

## Categories

AppDock organizes your apps into 13 categories:

| Category | Examples |
|----------|----------|
| Developer Tools | Xcode, VS Code, Terminal, Docker |
| Productivity | Pages, Notion, Obsidian, Calendar |
| Creativity & Design | Figma, Photoshop, Blender, Final Cut |
| Browsers & Internet | Safari, Chrome, Firefox, Arc |
| Communication | Slack, Teams, Discord, Mail |
| Media & Entertainment | Spotify, VLC, Apple Music, Netflix |
| Utilities | 1Password, CleanMyMac, Alfred |
| System | System Settings, Activity Monitor |
| Games | Steam, Chess |
| Education | Books, Dictionary |
| Finance | Stocks, QuickBooks |
| Health & Fitness | Health-related apps |
| Other | Uncategorized apps |

## License

MIT License. See [LICENSE](LICENSE) for details.
