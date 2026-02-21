import SwiftUI

struct LauncherView: View {
    var viewModel: LauncherViewModel

    // Category carousel drag state
    @State private var draggingCategory: AppCategory?
    @State private var categoryDragOffset: CGSize = .zero
    @State private var chipFrames: [String: CGRect] = [:]

    private let searchResultColumns = [
        GridItem(.adaptive(minimum: 88, maximum: 110), spacing: PlatformStyle.iconGridSpacing)
    ]

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
                    appIconBuilder: { app in appIcon(for: app) }
                )
                .padding(.horizontal, PlatformStyle.panelPadding)
                .padding(.bottom, PlatformStyle.panelPadding)
            } else {
                mainContent
            }
        }
        .frame(minWidth: PlatformStyle.panelMinWidth, maxWidth: PlatformStyle.panelMaxWidth, minHeight: 400, maxHeight: .infinity)
        .adaptiveGlassBackground()
        .onMouseBackButton { handleMouseBack() }
        .onAppear { viewModel.onAppear() }
        .onKeyPress(.escape) {
            handleEscape()
            return .handled
        }
        .onKeyPress(.upArrow) {
            viewModel.searchViewModel.moveHighlight(.up)
            return .handled
        }
        .onKeyPress(.downArrow) {
            viewModel.searchViewModel.moveHighlight(.down)
            return .handled
        }
        .onKeyPress(.leftArrow) {
            viewModel.searchViewModel.moveHighlight(.left)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            viewModel.searchViewModel.moveHighlight(.right)
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
                    appIcon(for: result.app)
                        .background(
                            RoundedRectangle(cornerRadius: PlatformStyle.appIconContainerRadius)
                                .fill(index == viewModel.searchViewModel.highlightedIndex
                                      ? Color.accentColor.opacity(0.15)
                                      : Color.clear)
                        )
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

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: PlatformStyle.sectionSpacing) {
                    // Pinned apps
                    if !viewModel.pinnedAppsViewModel.isEmpty {
                        PinnedAppsRow(
                            viewModel: viewModel.pinnedAppsViewModel,
                            onLaunchApp: { app in viewModel.launchApp(app) },
                            extraHorizontalPadding: viewModel.viewMode == .folders ? PlatformStyle.tilePaddingH / 2 - 4 : 0,
                            gridColumns: viewModel.viewMode == .list ? listColumns : nil,
                            gridSpacing: viewModel.viewMode == .list ? PlatformStyle.iconGridSpacing : nil
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
                            aggregateBadgeCount: { viewModel.badgeCount(for: $0) }
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
        if newMode == .folders {
            viewModel.selectedListCategory = nil
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
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(viewModel.categoryViewModel.nonEmptyCategories.filter { $0 != .other }) { category in
                        categoryChip(category: category)
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
        }
    }

    @State private var didDragMove = false

    private func categoryChip(category: AppCategory) -> some View {
        let isSelected = viewModel.selectedListCategory == category
        let isDragging = draggingCategory == category
        return HStack(spacing: 7) {
            Image(systemName: category.sfSymbol)
                .font(.system(size: 13))
                .foregroundStyle(category.color)
            Text(category.rawValue)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(isSelected ? Color.primary : .secondary)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.08))
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
        .gesture(
            LongPressGesture(minimumDuration: 0.25)
                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("categoryCarousel")))
                .onChanged { value in
                    switch value {
                    case .second(true, let drag):
                        if draggingCategory == nil {
                            draggingCategory = category
                            didDragMove = false
                        }
                        if let drag {
                            categoryDragOffset = drag.translation
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
                    withAnimation(.easeInOut(duration: 0.2)) {
                        draggingCategory = nil
                        categoryDragOffset = .zero
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
        let categories = viewModel.categoryViewModel.nonEmptyCategories.filter { $0 != .other }
        for (rawValue, frame) in chipFrames {
            guard rawValue != current.rawValue,
                  frame.contains(dragLocation),
                  let fromIndex = categories.firstIndex(of: current),
                  let target = categories.first(where: { $0.rawValue == rawValue }),
                  let toIndex = categories.firstIndex(of: target)
            else { continue }

            withAnimation(.easeInOut(duration: 0.2)) {
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
        VStack(alignment: .leading, spacing: PlatformStyle.sectionSpacing) {
            LazyVGrid(columns: listColumns, spacing: PlatformStyle.iconGridSpacing) {
                ForEach(viewModel.allAppsSorted) { app in
                    appIcon(for: app)
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
                    ForEach(viewModel.otherAppsSorted) { app in
                        appIcon(for: app)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func appIcon(for app: AppItem) -> some View {
        AppIconView(
            app: app,
            isPinned: viewModel.isAppPinned(app),
            canUninstall: viewModel.canUninstall(app),
            showNewDot: app.isNew,
            showUpdatedDot: app.isUpdated,
            badgeCount: viewModel.badgeCount(for: app),
            onLaunch: { viewModel.launchApp(app) },
            onPin: { viewModel.pinApp(app) },
            onUnpin: { viewModel.unpinApp(app) },
            onMoveToCategory: { category in viewModel.moveAppToCategory(app, category: category) },
            onAddToDock: { viewModel.addToDock(app) },
            onCreateShortcut: { viewModel.createDesktopShortcut(app) },
            onUninstall: { viewModel.requestUninstall(app) }
        )
    }

    private func handleMouseBack() {
        if viewModel.categoryViewModel.expandedCategory != nil {
            viewModel.categoryViewModel.collapseCategory()
            viewModel.searchViewModel.clearActiveFolder()
        } else if viewModel.selectedListCategory != nil {
            viewModel.selectedListCategory = nil
            viewModel.searchViewModel.clearActiveFolder()
        }
    }

    private func handleEscape() {
        if viewModel.searchViewModel.isActive {
            viewModel.searchViewModel.clearSearch()
        } else if viewModel.categoryViewModel.expandedCategory != nil {
            viewModel.categoryViewModel.collapseCategory()
            viewModel.searchViewModel.clearActiveFolder()
        } else {
            viewModel.onDismiss?()
        }
    }
}

private struct CategoryFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
