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
        onLaunch: @escaping () -> Void,
        onPin: (() -> Void)? = nil,
        onUnpin: (() -> Void)? = nil,
        onMoveToCategory: ((AppCategory) -> Void)? = nil,
        onAddToDock: (() -> Void)? = nil,
        onCreateShortcut: (() -> Void)? = nil,
        onUninstall: (() -> Void)? = nil
    ) {
        self.app = app
        self.size = size
        self.isPinned = isPinned
        self.canUninstall = canUninstall
        self.showLabel = showLabel
        self.onLaunch = onLaunch
        self.onPin = onPin
        self.onUnpin = onUnpin
        self.onMoveToCategory = onMoveToCategory
        self.onAddToDock = onAddToDock
        self.onCreateShortcut = onCreateShortcut
        self.onUninstall = onUninstall
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: IconExtractor.shared.icon(for: app.url, size: size))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)

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
                .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onLaunch() }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
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
                    Button(category.rawValue) {
                        onMoveToCategory?(category)
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
