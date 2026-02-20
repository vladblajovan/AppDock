import Foundation

@MainActor
final class CategoryClassifier {

    func classify(_ apps: [AppItem]) -> [AppItem] {
        apps.map { app in
            var classified = app
            classified.category = classifySingle(app)
            return classified
        }
    }

    func classifySingle(_ app: AppItem) -> AppCategory {
        // Layer 1: App Store metadata (LSApplicationCategoryType)
        if let storeCategory = app.appStoreCategory,
           let category = AppCategory(fromAppStoreCategory: storeCategory) {
            return category
        }

        // Layer 2: Exact bundle identifier match
        if let category = Self.exactBundleIDMap[app.bundleIdentifier] {
            return category
        }

        // Layer 3: Bundle identifier prefix match
        if let category = classifyByBundlePrefix(app.bundleIdentifier) {
            return category
        }

        // Layer 4: Apple app fallback — unrecognized com.apple.* apps go to System
        if app.bundleIdentifier.hasPrefix("com.apple.") {
            return .system
        }

        // Layer 5: Name-based keyword matching (word boundaries)
        if let category = classifyByName(app.name) {
            return category
        }

        return .other
    }

    // MARK: - Layer 2: Exact Bundle ID

    private static let exactBundleIDMap: [String: AppCategory] = [
        // Developer Tools — Apple
        "com.apple.dt.Xcode": .developerTools,
        "com.apple.Terminal": .developerTools,
        "com.apple.ScriptEditor2": .developerTools,
        "com.apple.Automator": .developerTools,

        // Developer Tools — Third Party
        "com.microsoft.VSCode": .developerTools,
        "com.visualstudio.code": .developerTools,
        "com.cursor.Cursor": .developerTools,
        "com.github.atom": .developerTools,
        "com.panic.Nova": .developerTools,
        "com.barebones.bbedit": .developerTools,
        "com.macromates.TextMate": .developerTools,
        "com.googlecode.iterm2": .developerTools,
        "dev.warp.Warp-Stable": .developerTools,
        "dev.warp.Warp": .developerTools,
        "co.zeit.hyper": .developerTools,
        "org.alacritty": .developerTools,
        "com.docker.docker": .developerTools,
        "com.tinyapp.TablePlus": .developerTools,
        "com.sequel-pro.sequel-pro": .developerTools,
        "com.postmanlabs.mac": .developerTools,
        "com.insomnia.app": .developerTools,
        "net.sourceforge.sqlitebrowser": .developerTools,
        "com.todesktop.230313mzl4w4u92": .developerTools, // Cursor
        "com.github.GitHubClient": .developerTools,
        "com.tower.mac": .developerTools,
        "com.git-tower.Tower3": .developerTools,
        "org.sourcetreeapp.SourceTree": .developerTools,
        "com.noodlesoft.Hazel": .developerTools,
        "abnerworks.Typora": .developerTools,
        "com.swiftformat.SwiftFormat-for-Xcode": .developerTools,

        // Browsers & Internet
        "com.google.Chrome": .browsersInternet,
        "com.google.Chrome.canary": .browsersInternet,
        "org.mozilla.firefox": .browsersInternet,
        "org.mozilla.nightly": .browsersInternet,
        "com.apple.Safari": .browsersInternet,
        "com.apple.SafariTechnologyPreview": .browsersInternet,
        "com.operasoftware.Opera": .browsersInternet,
        "com.brave.Browser": .browsersInternet,
        "com.vivaldi.Vivaldi": .browsersInternet,
        "org.chromium.Chromium": .browsersInternet,
        "company.thebrowser.Browser": .browsersInternet,
        "com.sigmaos.sigmaos.macos": .browsersInternet,
        "com.microsoft.edgemac": .browsersInternet,
        "org.torproject.torbrowser": .browsersInternet,
        "com.nickvision.Parabolic": .browsersInternet,

        // Communication
        "com.tinyspeck.slackmacgap": .communication,
        "com.microsoft.teams": .communication,
        "com.microsoft.teams2": .communication,
        "us.zoom.xos": .communication,
        "org.whispersystems.signal-desktop": .communication,
        "com.hnc.Discord": .communication,
        "ru.keepcoder.Telegram": .communication,
        "com.skype.skype": .communication,
        "com.apple.MobileSMS": .communication,
        "com.apple.FaceTime": .communication,
        "com.apple.mail": .communication,
        "com.apple.AddressBook": .communication,
        "com.apple.Contacts": .communication,
        "com.readdle.smartemail-macos": .communication,
        "com.microsoft.Outlook": .communication,
        "com.freron.MailMate": .communication,
        "com.mimestream.Mimestream": .communication,
        "com.superhuman.mail": .communication,
        "com.facebook.archon.developerID": .communication,
        "com.viber.osx": .communication,
        "jp.naver.line.mac": .communication,
        "com.linphone.linphone": .communication,

        // Media & Entertainment
        "com.spotify.client": .mediaEntertainment,
        "com.apple.Music": .mediaEntertainment,
        "com.apple.TV": .mediaEntertainment,
        "com.apple.iMovieApp": .mediaEntertainment,
        "com.apple.Photos": .mediaEntertainment,
        "com.apple.podcasts": .mediaEntertainment,
        "com.apple.QuickTimePlayerX": .mediaEntertainment,
        "com.apple.Image-Capture": .mediaEntertainment,
        "com.apple.VoiceMemos": .mediaEntertainment,
        "com.plexapp.plexmedia": .mediaEntertainment,
        "io.plex.plex-media-player": .mediaEntertainment,
        "com.colliderli.iina": .mediaEntertainment,
        "org.videolan.vlc": .mediaEntertainment,
        "com.netflix": .mediaEntertainment,
        "com.audacityteam.audacity": .mediaEntertainment,
        "com.amazon.aiv.AIVApp": .mediaEntertainment,
        "com.disneyplus.disneyplus": .mediaEntertainment,
        "com.app.hbogo": .mediaEntertainment,
        "com.apple.PhotoBooth": .mediaEntertainment,
        "com.apple.Preview": .mediaEntertainment,
        "com.handbrake.HandBrake": .mediaEntertainment,
        "org.bongo.bandcamp": .mediaEntertainment,
        "com.roon.Roon": .mediaEntertainment,
        "com.deezer.deezer-desktop": .mediaEntertainment,
        "com.tidal.desktop": .mediaEntertainment,

        // Productivity
        "com.microsoft.Word": .productivity,
        "com.microsoft.Excel": .productivity,
        "com.microsoft.Powerpoint": .productivity,
        "com.microsoft.onenote.mac": .productivity,
        "com.apple.iWork.Pages": .productivity,
        "com.apple.iWork.Numbers": .productivity,
        "com.apple.iWork.Keynote": .productivity,
        "com.apple.Notes": .productivity,
        "com.apple.reminders": .productivity,
        "com.apple.iCal": .productivity,
        "com.apple.Calendar": .productivity,
        "com.apple.Stickies": .productivity,
        "com.apple.shortcuts": .productivity,
        "com.todoist.mac.Todoist": .productivity,
        "com.culturedcode.ThingsMac": .productivity,
        "md.obsidian": .productivity,
        "com.notion.id": .productivity,
        "com.electron.logseq": .productivity,
        "com.lukilabs.lukiapp": .productivity,
        "com.flexibits.fantastical2.mac": .productivity,
        "com.flexibits.cardhop.mac": .productivity,
        "com.omnigroup.OmniFocus3": .productivity,
        "com.omnigroup.OmniGraffle7": .productivity,
        "com.omnigroup.OmniOutliner5": .productivity,
        "com.omnigroup.OmniPlan4": .productivity,
        "net.shinyfrog.bear": .productivity,
        "com.craft.craft": .productivity,
        "com.agiletortoise.Drafts-OSX": .productivity,
        "com.apple.Freeform": .productivity,

        // Creativity & Design
        "com.adobe.Photoshop": .creativityDesign,
        "com.adobe.Illustrator": .creativityDesign,
        "com.adobe.InDesign": .creativityDesign,
        "com.adobe.Premiere": .creativityDesign,
        "com.adobe.AfterEffects": .creativityDesign,
        "com.adobe.Lightroom": .creativityDesign,
        "com.adobe.LightroomClassicCC7": .creativityDesign,
        "com.adobe.AdobeMediaEncoder": .creativityDesign,
        "com.adobe.Animate": .creativityDesign,
        "com.adobe.Dreamweaver": .creativityDesign,
        "com.adobe.XD": .creativityDesign,
        "com.bohemiancoding.sketch3": .creativityDesign,
        "com.figma.Desktop": .creativityDesign,
        "com.canva.CanvaDesktop": .creativityDesign,
        "com.pixelmatorteam.pixelmator.x": .creativityDesign,
        "com.apple.garageband10": .creativityDesign,
        "com.apple.LogicPro": .creativityDesign,
        "com.apple.FinalCut": .creativityDesign,
        "com.apple.compressor": .creativityDesign,
        "com.apple.motion": .creativityDesign,
        "com.apple.MainStage": .creativityDesign,
        "com.blender.blender": .creativityDesign,
        "com.affinity.designer2": .creativityDesign,
        "com.affinity.photo2": .creativityDesign,
        "com.affinity.publisher2": .creativityDesign,
        "com.affinity.designer": .creativityDesign,
        "com.affinity.photo": .creativityDesign,
        "com.affinity.publisher": .creativityDesign,
        "com.procreate.Procreate": .creativityDesign,
        "com.corel.coreldraw": .creativityDesign,
        "com.davinci.resolve": .creativityDesign,
        "com.blackmagic-design.DaVinciResolve": .creativityDesign,
        "com.zbrush.zbrush": .creativityDesign,

        // Utilities
        "com.apple.calculator": .utilities,
        "com.apple.ActivityMonitor": .utilities,
        "com.apple.DiskUtility": .utilities,
        "com.apple.ScreenCapture": .utilities,
        "com.apple.TextEdit": .utilities,
        "com.apple.ColorSyncUtility": .utilities,
        "com.apple.DigitalColorMeter": .utilities,
        "com.apple.KeychainAccess": .utilities,
        "com.apple.FontBook": .utilities,
        "com.apple.Maps": .utilities,
        "com.apple.Weather": .utilities,
        "com.apple.Home": .utilities,
        "com.apple.findmy": .utilities,
        "com.apple.ScreenSaver.Engine": .utilities,
        "com.apple.ScreenSharing": .utilities,
        "com.apple.airport.airportutility": .utilities,
        "com.apple.Grapher": .utilities,
        "com.apple.BluetoothFileExchange": .utilities,
        "com.apple.print.PrinterProxy": .utilities,
        "com.apple.DirectoryUtility": .utilities,
        "com.apple.Console": .utilities,
        "com.apple.SystemProfiler": .utilities,
        "com.apple.audio.AudioMIDISetup": .utilities,
        "com.apple.Clock": .utilities,
        "com.1password": .utilities,
        "com.1password.1password": .utilities,
        "com.agilebits.onepassword7": .utilities,
        "com.bitwarden.desktop": .utilities,
        "com.nordvpn.macos": .utilities,
        "com.expressvpn.ExpressVPN": .utilities,
        "com.objective-see.lulu": .utilities,
        "com.macpaw.CleanMyMac4": .utilities,
        "com.macpaw.CleanMyMac-setapp": .utilities,
        "org.p0deje.Maccy": .utilities,
        "com.raycast.macos": .utilities,
        "com.alfredapp.Alfred": .utilities,
        "com.eltima.cmd1-setapp": .utilities,
        "com.pilotmoon.popclip": .utilities,
        "com.bartender.Bartender": .utilities,
        "com.apphousekitchen.aldente-pro": .utilities,
        "me.guillaumeb.MonitorControl": .utilities,
        "com.surteesstudios.Bartender": .utilities,
        "com.lwouis.alt-tab-macos": .utilities,
        "com.hegenberg.BetterTouchTool": .utilities,
        "com.manytricks.Moom": .utilities,
        "com.crystalidea.macsfancontrol": .utilities,
        "at.obdev.LittleSnitchConfiguration": .utilities,
        "com.nssurge.surge-mac": .utilities,
        "com.sparklabs.Viscosity": .utilities,
        "com.apple.AppStore": .utilities,

        // System
        "com.apple.systempreferences": .system,
        "com.apple.SystemPreferences": .system,
        "com.apple.Accessibility": .system,
        "com.apple.MigrateAssistant": .system,
        "com.apple.bootcampassistant": .system,
        "com.apple.SoftwareUpdate": .system,
        "com.apple.installer": .system,

        // Finance
        "com.copperkit.Cashculator-Mac": .finance,
        "com.apple.stocks": .finance,

        // Education
        "com.apple.iBooks": .education,
        "com.apple.Dictionary": .education,

        // Games
        "com.apple.Chess": .games,
    ]

    // MARK: - Layer 3: Bundle ID Prefix

    private func classifyByBundlePrefix(_ bundleID: String) -> AppCategory? {
        let id = bundleID.lowercased()

        for (prefix, category) in Self.bundlePrefixMap {
            if id.hasPrefix(prefix) {
                return category
            }
        }

        return nil
    }

    private static let bundlePrefixMap: [(String, AppCategory)] = [
        // Developer Tools
        ("com.apple.dt.", .developerTools),
        ("com.jetbrains.", .developerTools),
        ("com.sublimetext.", .developerTools),
        ("com.sublimehq.", .developerTools),

        // Adobe → Creativity
        ("com.adobe.", .creativityDesign),

        // Microsoft Office → Productivity
        ("com.microsoft.word", .productivity),
        ("com.microsoft.excel", .productivity),
        ("com.microsoft.powerpoint", .productivity),

        // Browsers
        ("com.google.chrome", .browsersInternet),
        ("org.mozilla.", .browsersInternet),

        // Communication
        ("com.microsoft.teams", .communication),
        ("com.microsoft.outlook", .communication),
    ]

    // MARK: - Layer 5: Name-based Keyword Matching

    private func classifyByName(_ name: String) -> AppCategory? {
        let words = Set(
            name.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
        )

        for (keyword, category) in Self.nameKeywords {
            if words.contains(keyword) {
                return category
            }
        }

        return nil
    }

    private static let nameKeywords: [(String, AppCategory)] = [
        // Developer Tools
        ("xcode", .developerTools),
        ("terminal", .developerTools),
        ("compiler", .developerTools),
        ("debugger", .developerTools),

        // Browsers
        ("safari", .browsersInternet),
        ("chrome", .browsersInternet),
        ("firefox", .browsersInternet),
        ("browser", .browsersInternet),

        // Communication
        ("mail", .communication),
        ("chat", .communication),
        ("messenger", .communication),
        ("slack", .communication),

        // Media & Entertainment
        ("music", .mediaEntertainment),
        ("podcast", .mediaEntertainment),
        ("radio", .mediaEntertainment),

        // Creativity & Design
        ("design", .creativityDesign),
        ("sketch", .creativityDesign),
        ("paint", .creativityDesign),
        ("illustrator", .creativityDesign),

        // Games
        ("game", .games),
        ("chess", .games),
        ("arcade", .games),
        ("solitaire", .games),
        ("sudoku", .games),

        // Utilities
        ("vpn", .utilities),
        ("calculator", .utilities),
        ("clipboard", .utilities),
        ("password", .utilities),
        ("unarchiver", .utilities),

        // Education
        ("classroom", .education),

        // Finance
        ("finance", .finance),
        ("banking", .finance),
        ("budget", .finance),
        ("accounting", .finance),
        ("invoice", .finance),
    ]
}
