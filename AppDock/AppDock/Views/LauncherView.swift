import SwiftUI

struct LauncherView: View {
    var viewModel: LauncherViewModel

    // Category carousel drag state
    @State private var draggingCategory: AppCategory?
    @State private var categoryDragOffset: CGSize = .zero
    @State private var categoryDragBaseOffset: CGSize = .zero
    @State private var chipFrames: [String: CGRect] = [:]

    /// Measured width of the grid content area (inside horizontal padding).
    @State private var gridContentWidth: CGFloat = 0

    /// Whether the cursor is hidden due to keyboard navigation.
    @State private var isCursorHidden = false
    @State private var mouseMoveMonitor: Any?

    private let searchResultColumns = [
        GridItem(.adaptive(minimum: 88, maximum: 110), spacing: PlatformStyle.iconGridSpacing)
    ]

    /// Compute how many columns fit for an adaptive grid given the measured width.
    private static func adaptiveColumns(width: CGFloat, minimum: CGFloat, spacing: CGFloat) -> Int {
        guard width > 0 else { return 1 }
        return max(1, Int((width + spacing) / (minimum + spacing)))
    }

    /// Actual columns per row for the current main content grid.
    private var currentColumnsPerRow: Int {
        if viewModel.viewMode == .folders && viewModel.categoryViewModel.expandedCategory == nil {
            return Self.adaptiveColumns(width: gridContentWidth, minimum: 180, spacing: PlatformStyle.categoryGridSpacing)
        }
        return Self.adaptiveColumns(width: gridContentWidth, minimum: 100, spacing: PlatformStyle.iconGridSpacing)
    }

    /// Actual columns per row for the pinned apps grid.
    private var pinnedColumnsPerRow: Int {
        if viewModel.viewMode == .list {
            return Self.adaptiveColumns(width: gridContentWidth, minimum: 100, spacing: PlatformStyle.iconGridSpacing)
        }
        return Self.adaptiveColumns(width: gridContentWidth, minimum: PlatformStyle.appIconSize + 20, spacing: PlatformStyle.iconGridSpacing)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar with header controls — always visible; also acts as window drag handle
            HStack(spacing: 10) {
                SearchBarView(
                    viewModel: viewModel.searchViewModel,
                    showBackButton: (viewModel.viewMode == .list && viewModel.selectedListCategory != nil)
                        || viewModel.categoryViewModel.expandedCategory != nil,
                    showFolderChip: viewModel.viewMode == .folders
                )

                Picker("", selection: viewModeBinding) {
                    Image(systemName: "square.grid.2x2").tag(AppViewMode.folders)
                    Image(systemName: "list.bullet").tag(AppViewMode.list)
                }
                .pickerStyle(.segmented)
                .controlSize(.extraLarge)
                .frame(width: 100)
            }
            .padding(.leading, PlatformStyle.panelPadding)
            .padding(.trailing, PlatformStyle.panelPadding / 2)
            .padding(.top, PlatformStyle.panelPadding)
            .padding(.bottom, 16)
            .background(WindowDragView())

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.searchViewModel.isActive {
                searchResultsView
            } else if let expanded = viewModel.categoryViewModel.expandedCategory, !viewModel.searchViewModel.isActive {
                CategoryDetailView(
                    category: expanded,
                    apps: viewModel.categoryViewModel.appsForCategory(expanded),
                    appIconBuilder: { app, highlighted in appIcon(for: app, isHighlighted: highlighted) },
                    highlightedIndex: viewModel.highlightedSection == .main ? viewModel.highlightedItemIndex : nil
                )
                .padding(.horizontal, PlatformStyle.panelPadding)
                .padding(.bottom, PlatformStyle.panelPadding)
            } else {
                mainContent
            }
        }
        .frame(minWidth: PlatformStyle.panelMinWidth, maxWidth: PlatformStyle.panelMaxWidth, minHeight: 400, maxHeight: .infinity)
        .adaptiveGlassBackground()
        .background(GeometryReader { geo in
            Color.clear.onAppear {
                gridContentWidth = geo.size.width - PlatformStyle.panelPadding * 2
            }
            .onChange(of: geo.size.width) { _, newWidth in
                gridContentWidth = newWidth - PlatformStyle.panelPadding * 2
            }
        })
        .onAppear { viewModel.onAppear() }
        .onDisappear { showCursorIfNeeded() }
        .onKeyPress(.escape) {
            handleEscape()
            return .handled
        }
        .onKeyPress(.upArrow) {
            hideCursorForKeyboardNav()
            if viewModel.searchViewModel.isActive {
                viewModel.searchViewModel.moveHighlight(.up)
            } else {
                viewModel.moveHighlightInBrowse(.up, columnsPerRow: currentColumnsPerRow, pinnedColumnsPerRow: pinnedColumnsPerRow)
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            hideCursorForKeyboardNav()
            if viewModel.searchViewModel.isActive {
                viewModel.searchViewModel.moveHighlight(.down)
            } else {
                viewModel.moveHighlightInBrowse(.down, columnsPerRow: currentColumnsPerRow, pinnedColumnsPerRow: pinnedColumnsPerRow)
            }
            return .handled
        }
        .onKeyPress(.leftArrow) {
            hideCursorForKeyboardNav()
            if viewModel.searchViewModel.isActive {
                viewModel.searchViewModel.moveHighlight(.left)
            } else {
                viewModel.moveHighlightInBrowse(.left, columnsPerRow: currentColumnsPerRow, pinnedColumnsPerRow: pinnedColumnsPerRow)
            }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            hideCursorForKeyboardNav()
            if viewModel.searchViewModel.isActive {
                viewModel.searchViewModel.moveHighlight(.right)
            } else {
                viewModel.moveHighlightInBrowse(.right, columnsPerRow: currentColumnsPerRow, pinnedColumnsPerRow: pinnedColumnsPerRow)
            }
            return .handled
        }
        .onKeyPress(.return) {
            if !viewModel.searchViewModel.isActive, viewModel.highlightedItemIndex != nil {
                viewModel.activateHighlightedItem()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(characters: .decimalDigits) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            return launchPinnedApp(for: press)
        }
        .onKeyPress(.tab) {
            setViewMode(viewModel.viewMode == .folders ? .list : .folders)
            return .handled
        }
        // Uninstall confirmation
        .alert(
            "Uninstall \"\(viewModel.appPendingUninstall?.name ?? "")\"?",
            isPresented: Binding(
                get: { viewModel.appPendingUninstall != nil },
                set: { if !$0 { viewModel.cancelUninstall() } }
            )
        ) {
            Button("Cancel", role: .cancel) { viewModel.cancelUninstall() }
            Button("Move to Trash", role: .destructive) {
                Task { await viewModel.confirmUninstall() }
            }
        } message: {
            Text("This will move \"\(viewModel.appPendingUninstall?.name ?? "")\" to the Trash. You can restore it from the Trash if needed.")
        }
        // Uninstall error
        .alert(
            "Uninstall Failed",
            isPresented: Binding(
                get: { viewModel.uninstallError != nil },
                set: { if !$0 { viewModel.dismissUninstallError() } }
            )
        ) {
            Button("OK") { viewModel.dismissUninstallError() }
        } message: {
            Text(viewModel.uninstallError ?? "")
        }
    }

    // MARK: - Search Results

    private var searchResultsView: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: searchResultColumns, spacing: PlatformStyle.iconGridSpacing) {
                ForEach(Array(viewModel.searchViewModel.results.enumerated()), id: \.element.app.id) { index, result in
                    appIcon(for: result.app, isHighlighted: index == viewModel.searchViewModel.highlightedIndex)
                }
            }
            .padding(.horizontal, PlatformStyle.panelPadding)
            .padding(.bottom, PlatformStyle.panelPadding)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .clipped()
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: PlatformStyle.sectionSpacing) {
            if viewModel.viewMode == .list {
                categoryCarousel
                    .padding(.horizontal, PlatformStyle.panelPadding)
                    .padding(.top, 4)
            }

            ScrollViewReader { scrollProxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: PlatformStyle.sectionSpacing) {
                        // Pinned apps (hidden in list mode when a category is selected)
                        if !viewModel.pinnedAppsViewModel.isEmpty && !(viewModel.viewMode == .list && viewModel.selectedListCategory != nil) {
                            PinnedAppsRow(
                                viewModel: viewModel.pinnedAppsViewModel,
                                onLaunchApp: { app in viewModel.launchApp(app) },
                                extraHorizontalPadding: viewModel.viewMode == .folders ? PlatformStyle.tilePaddingH / 2 - 4 : 0,
                                gridColumns: viewModel.viewMode == .list ? listColumns : nil,
                                gridSpacing: viewModel.viewMode == .list ? PlatformStyle.iconGridSpacing : nil,
                                highlightedIndex: viewModel.highlightedSection == .pinned ? viewModel.highlightedItemIndex : nil,
                                suppressHover: viewModel.isKeyboardNavigating,
                                onHoverChanged: { hovering in
                                    if hovering && !viewModel.isKeyboardNavigating { viewModel.highlightedItemIndex = nil }
                                }
                            )
                            Divider()
                        }

                        if viewModel.viewMode == .folders {
                            CategoryGridView(
                                viewModel: viewModel.categoryViewModel,
                                onLaunchApp: { app in viewModel.launchApp(app) },
                                onExpandCategory: { category in
                                    let apps = viewModel.categoryViewModel.appsForCategory(category)
                                    viewModel.searchViewModel.setActiveFolder(category, apps: apps)
                                },
                                hasNewOrUpdatedApps: { viewModel.hasNewOrUpdatedApps(in: $0) },
                                aggregateBadgeCount: { viewModel.badgeCount(for: $0) },
                                highlightedIndex: viewModel.highlightedSection == .main ? viewModel.highlightedItemIndex : nil,
                                suppressHover: viewModel.isKeyboardNavigating,
                                onHoverChanged: { hovering in
                                    if hovering && !viewModel.isKeyboardNavigating { viewModel.highlightedItemIndex = nil }
                                }
                            )
                            .padding(.top, 14)
                        } else {
                            allAppsListView
                                .padding(.top, 14)
                        }
                    }
                    .padding(.horizontal, PlatformStyle.panelPadding)
                    .padding(.bottom, PlatformStyle.panelPadding)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .clipped()
                .onChange(of: viewModel.highlightedItemIndex) { _, newIndex in
                    guard let idx = newIndex,
                          let scrollID = scrollIDForHighlight(section: viewModel.highlightedSection, index: idx)
                    else { return }
                    scrollProxy.scrollTo(scrollID)
                }
                .onChange(of: viewModel.highlightedSection) { _, newSection in
                    guard let idx = viewModel.highlightedItemIndex,
                          let scrollID = scrollIDForHighlight(section: newSection, index: idx)
                    else { return }
                    scrollProxy.scrollTo(scrollID)
                }
            }
            .mask(
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 0)
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 12)
                }
            )
        }
    }

    // MARK: - Header Controls

    private var viewModeBinding: Binding<AppViewMode> {
        Binding(
            get: { viewModel.viewMode },
            set: { setViewMode($0) }
        )
    }

    private func setViewMode(_ newMode: AppViewMode) {
        viewModel.viewMode = newMode
        viewModel.highlightedItemIndex = nil
        if newMode == .folders {
            viewModel.selectedListCategory = nil
            viewModel.searchViewModel.clearActiveFolder()
        } else {
            // Collapse any expanded folder so list mode is shown immediately
            viewModel.categoryViewModel.collapseCategory()
            viewModel.searchViewModel.clearActiveFolder()
        }
    }

    private var headerControls: some View {
        HStack {
            Text("Apps")
                .font(PlatformStyle.sectionHeaderFont)
                .foregroundStyle(.secondary)

            Spacer()

            if #available(macOS 26, *) {
                Button {
                    viewModel.onShowSettings?()
                } label: {
                    Image(systemName: "gearshape")
                        .padding(6)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive())
                .controlSize(.large)
            } else {
                Button {
                    viewModel.onShowSettings?()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }

            Picker("", selection: viewModeBinding) {
                Image(systemName: "square.grid.2x2").tag(AppViewMode.folders)
                Image(systemName: "list.bullet").tag(AppViewMode.list)
            }
            .pickerStyle(.segmented)
            .controlSize(.large)
            .frame(width: 90)
        }
    }

    // MARK: - Category Carousel

    private var categoryCarousel: some View {
        let highlightedCategoryIndex = viewModel.highlightedSection == .categories ? viewModel.highlightedItemIndex : nil
        return ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(Array(viewModel.carouselCategories.enumerated()), id: \.element) { index, category in
                        categoryChip(category: category, isKeyboardHighlighted: index == highlightedCategoryIndex)
                            .id(category)
                    }
                }
                .padding(.trailing, 4)
                .coordinateSpace(name: "categoryCarousel")
                .onPreferenceChange(CategoryFramePreferenceKey.self) { frames in
                    chipFrames = frames
                }
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(draggingCategory != nil)
            .onChange(of: highlightedCategoryIndex) { _, newIndex in
                guard let idx = newIndex else { return }
                let cats = viewModel.carouselCategories
                guard idx < cats.count else { return }
                withAnimation(.easeOut(duration: 0.08)) {
                    proxy.scrollTo(cats[idx], anchor: .center)
                }
            }
        }
    }

    @State private var didDragMove = false

    private func categoryChip(category: AppCategory, isKeyboardHighlighted: Bool = false) -> some View {
        let isSelected = viewModel.selectedListCategory == category
        let isDragging = draggingCategory == category
        return HStack(spacing: 7) {
            Image(systemName: category.sfSymbol)
                .font(.system(size: 13))
                .foregroundStyle(category.color)
            Text(category.rawValue)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(isSelected || isKeyboardHighlighted ? Color.primary : .secondary)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isSelected ? Color.accentColor.opacity(0.2) : isKeyboardHighlighted ? Color.primary.opacity(0.15) : Color.primary.opacity(0.08))
        )
        .contentShape(Capsule())
        .opacity(isDragging ? 0.5 : 1)
        .scaleEffect(isDragging ? 1.05 : 1)
        .offset(isDragging ? categoryDragOffset : .zero)
        .zIndex(isDragging ? 1 : 0)
        .background(GeometryReader { geo in
            Color.clear.preference(
                key: CategoryFramePreferenceKey.self,
                value: [category.rawValue: geo.frame(in: .named("categoryCarousel"))]
            )
        })
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.2)
                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("categoryCarousel")))
                .onChanged { value in
                    switch value {
                    case .second(true, let drag):
                        if draggingCategory == nil {
                            draggingCategory = category
                            categoryDragBaseOffset = .zero
                            didDragMove = false
                        }
                        if let drag {
                            categoryDragOffset = CGSize(
                                width: drag.translation.width + categoryDragBaseOffset.width,
                                height: drag.translation.height + categoryDragBaseOffset.height
                            )
                            if abs(drag.translation.width) > 2 || abs(drag.translation.height) > 2 {
                                didDragMove = true
                            }
                            checkForCategoryReorder(dragLocation: drag.location, current: category)
                        }
                    default:
                        break
                    }
                }
                .onEnded { _ in
                    let wasDrag = didDragMove
                    withAnimation(.easeOut(duration: 0.08)) {
                        draggingCategory = nil
                        categoryDragOffset = .zero
                        categoryDragBaseOffset = .zero
                    }
                    // If the user long-pressed without dragging, treat as a tap
                    if !wasDrag {
                        handleCategoryTap(category)
                    }
                    didDragMove = false
                }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    guard draggingCategory == nil else { return }
                    handleCategoryTap(category)
                }
        )
    }

    private func handleCategoryTap(_ category: AppCategory) {
        viewModel.highlightedItemIndex = nil
        if viewModel.selectedListCategory == category {
            viewModel.selectedListCategory = nil
            viewModel.searchViewModel.clearActiveFolder()
        } else {
            viewModel.selectedListCategory = category
            let apps = viewModel.categoryViewModel.appsForCategory(category)
            viewModel.searchViewModel.setActiveFolder(category, apps: apps)
        }
    }

    private func checkForCategoryReorder(dragLocation: CGPoint, current: AppCategory) {
        guard let currentFrame = chipFrames[current.rawValue] else { return }
        let categories = viewModel.categoryViewModel.nonEmptyCategories.filter { $0 != .other }
        for (rawValue, frame) in chipFrames {
            guard rawValue != current.rawValue,
                  frame.contains(dragLocation),
                  let fromIndex = categories.firstIndex(of: current),
                  let target = categories.first(where: { $0.rawValue == rawValue }),
                  let toIndex = categories.firstIndex(of: target)
            else { continue }

            // Adjust base offset so the chip stays under the cursor after the swap
            categoryDragBaseOffset = CGSize(
                width: categoryDragBaseOffset.width + (currentFrame.midX - frame.midX),
                height: categoryDragBaseOffset.height + (currentFrame.midY - frame.midY)
            )

            withAnimation(.easeOut(duration: 0.08)) {
                viewModel.categoryViewModel.moveCategory(
                    from: IndexSet(integer: fromIndex),
                    to: toIndex > fromIndex ? toIndex + 1 : toIndex
                )
            }
            break
        }
    }

    // MARK: - All Apps List

    private let listColumns = [
        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: PlatformStyle.iconGridSpacing)
    ]

    private var allAppsListView: some View {
        let mainApps = viewModel.allAppsSorted
        let mainCount = mainApps.count
        let mainHighlight = viewModel.highlightedSection == .main ? viewModel.highlightedItemIndex : nil
        return VStack(alignment: .leading, spacing: PlatformStyle.sectionSpacing) {
            LazyVGrid(columns: listColumns, spacing: PlatformStyle.iconGridSpacing) {
                ForEach(Array(mainApps.enumerated()), id: \.element.id) { index, app in
                    appIcon(for: app, isHighlighted: index == mainHighlight)
                        .id("main-\(app.bundleIdentifier)")
                }
            }

            if viewModel.selectedListCategory == nil && !viewModel.otherAppsSorted.isEmpty {
                Divider()

                HStack(spacing: 5) {
                    Image(systemName: AppCategory.other.sfSymbol)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Text("Other")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: listColumns, spacing: PlatformStyle.iconGridSpacing) {
                    ForEach(Array(viewModel.otherAppsSorted.enumerated()), id: \.element.id) { index, app in
                        appIcon(for: app, isHighlighted: (index + mainCount) == mainHighlight)
                            .id("other-\(app.bundleIdentifier)")
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Maps a highlighted section + index to the `.id()` value used on the corresponding view.
    private func scrollIDForHighlight(section: BrowseSection, index: Int) -> String? {
        switch section {
        case .categories:
            // Categories carousel handles its own scrolling via ScrollViewReader
            return nil
        case .pinned:
            let pinned = viewModel.pinnedAppsViewModel.pinnedApps
            guard index < pinned.count else { return nil }
            return "pinned-\(pinned[index].bundleIdentifier)"
        case .main:
            if viewModel.viewMode == .folders {
                if let expanded = viewModel.categoryViewModel.expandedCategory {
                    let apps = viewModel.categoryViewModel.appsForCategory(expanded)
                    guard index < apps.count else { return nil }
                    return apps[index].bundleIdentifier
                } else {
                    let categories = viewModel.categoryViewModel.nonEmptyCategories
                    guard index < categories.count else { return nil }
                    return categories[index].rawValue
                }
            } else {
                let mainApps = viewModel.allAppsSorted
                if index < mainApps.count {
                    return "main-\(mainApps[index].bundleIdentifier)"
                }
                let otherIndex = index - mainApps.count
                let others = viewModel.otherAppsSorted
                guard otherIndex < others.count else { return nil }
                return "other-\(others[otherIndex].bundleIdentifier)"
            }
        }
    }

    private func appIcon(for app: AppItem, isHighlighted: Bool = false) -> some View {
        AppIconView(
            app: app,
            isPinned: viewModel.isAppPinned(app),
            canUninstall: viewModel.canUninstall(app),
            showNewDot: app.isNew,
            showUpdatedDot: app.isUpdated,
            badgeCount: viewModel.badgeCount(for: app),
            isHighlighted: isHighlighted,
            suppressHover: viewModel.isKeyboardNavigating,
            onLaunch: { viewModel.launchApp(app) },
            onPin: { viewModel.pinApp(app) },
            onUnpin: { viewModel.unpinApp(app) },
            onMoveToCategory: { category in viewModel.moveAppToCategory(app, category: category) },
            onAddToDock: { viewModel.addToDock(app) },
            onCreateShortcut: { viewModel.createDesktopShortcut(app) },
            onUninstall: { viewModel.requestUninstall(app) },
            onHoverChanged: { hovering in
                if hovering && !viewModel.isKeyboardNavigating { viewModel.highlightedItemIndex = nil }
            }
        )
    }

    private func launchPinnedApp(for press: KeyPress) -> KeyPress.Result {
        guard let digit = press.characters.first?.wholeNumberValue,
              digit >= 1, digit <= 9 else { return .ignored }
        let pinned = viewModel.pinnedAppsViewModel.pinnedApps
        let index = digit - 1
        guard index < pinned.count else { return .ignored }
        viewModel.launchApp(pinned[index])
        return .handled
    }

    private func handleEscape() {
        viewModel.highlightedItemIndex = nil
        showCursorIfNeeded()
        if viewModel.searchViewModel.isActive {
            viewModel.searchViewModel.clearSearch()
        } else if viewModel.categoryViewModel.expandedCategory != nil {
            viewModel.categoryViewModel.collapseCategory()
            viewModel.searchViewModel.clearActiveFolder()
        } else if viewModel.selectedListCategory != nil {
            viewModel.selectedListCategory = nil
            viewModel.searchViewModel.clearActiveFolder()
        } else {
            viewModel.onDismiss?()
        }
    }

    // MARK: - Cursor Management

    private func hideCursorForKeyboardNav() {
        guard !isCursorHidden else { return }
        isCursorHidden = true
        viewModel.isKeyboardNavigating = true
        NSCursor.hide()

        // Install a local monitor that fires when the mouse actually moves
        mouseMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { event in
            showCursorIfNeeded()
            return event
        }
    }

    private func showCursorIfNeeded() {
        guard isCursorHidden else { return }
        isCursorHidden = false
        viewModel.isKeyboardNavigating = false
        NSCursor.unhide()

        if let monitor = mouseMoveMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMoveMonitor = nil
        }
    }
}

private struct CategoryFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
