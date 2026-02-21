import SwiftUI

struct AppIconView: View {
    let app: AppItem
    let size: CGFloat
    let onLaunch: () -> Void
    var isPinned: Bool = false
    var canUninstall: Bool = false
    var onPin: (() -> Void)?
    var onUnpin: (() -> Void)?
    var onMoveToCategory: ((AppCategory) -> Void)?
    var onAddToDock: (() -> Void)?
    var onCreateShortcut: (() -> Void)?
    var onUninstall: (() -> Void)?
    var showLabel: Bool?
    var showNewDot: Bool = false
    var showUpdatedDot: Bool = false
    var badgeCount: Int = 0
    var isHighlighted: Bool = false
    var suppressHover: Bool = false
    var onHoverChanged: ((Bool) -> Void)?

    @AppStorage("showAppNames") private var showAppNames: Bool = true
    @State private var isHovered = false

    private var shouldShowName: Bool {
        showLabel ?? showAppNames
    }

    init(
        app: AppItem,
        size: CGFloat = PlatformStyle.appIconSize,
        isPinned: Bool = false,
        canUninstall: Bool = false,
        showLabel: Bool? = nil,
        showNewDot: Bool = false,
        showUpdatedDot: Bool = false,
        badgeCount: Int = 0,
        isHighlighted: Bool = false,
        suppressHover: Bool = false,
        onLaunch: @escaping () -> Void,
        onPin: (() -> Void)? = nil,
        onUnpin: (() -> Void)? = nil,
        onMoveToCategory: ((AppCategory) -> Void)? = nil,
        onAddToDock: (() -> Void)? = nil,
        onCreateShortcut: (() -> Void)? = nil,
        onUninstall: (() -> Void)? = nil,
        onHoverChanged: ((Bool) -> Void)? = nil
    ) {
        self.app = app
        self.size = size
        self.isPinned = isPinned
        self.canUninstall = canUninstall
        self.showLabel = showLabel
        self.showNewDot = showNewDot
        self.showUpdatedDot = showUpdatedDot
        self.badgeCount = badgeCount
        self.isHighlighted = isHighlighted
        self.suppressHover = suppressHover
        self.onLaunch = onLaunch
        self.onPin = onPin
        self.onUnpin = onUnpin
        self.onMoveToCategory = onMoveToCategory
        self.onAddToDock = onAddToDock
        self.onCreateShortcut = onCreateShortcut
        self.onUninstall = onUninstall
        self.onHoverChanged = onHoverChanged
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: IconExtractor.shared.icon(for: app.url, size: size, bundleIdentifier: app.bundleIdentifier))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .overlay(alignment: .topTrailing) {
                    if showNewDot {
                        Circle()
                            .fill(.blue)
                            .frame(width: 10, height: 10)
                            .alignmentGuide(.top) { $0[VerticalAlignment.center] }
                            .alignmentGuide(.trailing) { $0[HorizontalAlignment.center] }
                    } else if showUpdatedDot {
                        Circle()
                            .fill(.orange)
                            .frame(width: 10, height: 10)
                            .alignmentGuide(.top) { $0[VerticalAlignment.center] }
                            .alignmentGuide(.trailing) { $0[HorizontalAlignment.center] }
                    } else if badgeCount > 0 {
                        BadgeLabelView(count: badgeCount)
                            .alignmentGuide(.top) { $0[VerticalAlignment.center] }
                            .alignmentGuide(.trailing) { $0[HorizontalAlignment.center] }
                    }
                }

            if shouldShowName {
                Text(app.name)
                    .font(PlatformStyle.appLabelFont)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                    .frame(width: size + 16, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: shouldShowName ? size + 40 : size, alignment: .top)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: PlatformStyle.appIconContainerRadius)
                .fill(((isHovered && !suppressHover) || isHighlighted) ? Color.primary.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onLaunch() }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
            onHoverChanged?(hovering)
        }
        .contextMenu { contextMenuContent }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        Button("Open") { onLaunch() }

        Divider()

        if isPinned {
            Button("Unpin") { onUnpin?() }
        } else {
            Button("Pin to Top") { onPin?() }
        }

        if onMoveToCategory != nil {
            Menu("Move to Category") {
                ForEach(AppCategory.allCases) { category in
                    Button {
                        onMoveToCategory?(category)
                    } label: {
                        if category == app.category {
                            Label(category.rawValue, systemImage: "checkmark")
                        } else {
                            Text(category.rawValue)
                        }
                    }
                }
            }
        }

        Divider()

        if onAddToDock != nil {
            Button("Add to Dock") { onAddToDock?() }
        }

        if onCreateShortcut != nil {
            Button("Create Desktop Shortcut") { onCreateShortcut?() }
        }

        Divider()

        if onUninstall != nil {
            Button("Uninstall...", role: .destructive) { onUninstall?() }
                .disabled(!canUninstall)
        }

        Divider()

        Button("Show in Finder") {
            NSWorkspace.shared.selectFile(app.url.path, inFileViewerRootedAtPath: app.url.deletingLastPathComponent().path)
        }
    }
}
