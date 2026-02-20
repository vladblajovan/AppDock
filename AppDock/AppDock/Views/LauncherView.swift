import SwiftUI

struct LauncherView: View {
    var viewModel: LauncherViewModel

    private let searchResultColumns = [
        GridItem(.adaptive(minimum: 88, maximum: 110), spacing: PlatformStyle.iconGridSpacing)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Search bar — always visible; also acts as window drag handle
            SearchBarView(viewModel: viewModel.searchViewModel)
                .padding(.horizontal, PlatformStyle.panelPadding)
                .padding(.top, PlatformStyle.panelPadding)
                .padding(.bottom, PlatformStyle.sectionSpacing)
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
                    onBack: {
                        viewModel.categoryViewModel.collapseCategory()
                        viewModel.searchViewModel.clearActiveFolder()
                    },
                    appIconBuilder: { app in appIcon(for: app) }
                )
                .padding(.horizontal, PlatformStyle.panelPadding)
                .padding(.bottom, PlatformStyle.panelPadding)
                .onMouseBackButton {
                    viewModel.categoryViewModel.collapseCategory()
                    viewModel.searchViewModel.clearActiveFolder()
                }
            } else {
                mainContent
            }
        }
        .frame(minWidth: PlatformStyle.panelWidth, maxWidth: PlatformStyle.panelWidth, minHeight: 400, maxHeight: .infinity)
        .adaptiveGlassBackground()
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
        ScrollView(.vertical, showsIndicators: false) {
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
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .clipped()
        .padding(.bottom, PlatformStyle.panelPadding)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: PlatformStyle.sectionSpacing) {
                Spacer().frame(height: 4)
                // Pinned apps
                if !viewModel.pinnedAppsViewModel.isEmpty {
                    PinnedAppsRow(
                        viewModel: viewModel.pinnedAppsViewModel,
                        onLaunchApp: { app in viewModel.launchApp(app) }
                    )
                    .padding(.horizontal, PlatformStyle.panelPadding)

                    Divider()
                        .padding(.horizontal, PlatformStyle.panelPadding)
                }

                // Categories / List header
                HStack {
                    Text("Apps")
                        .font(PlatformStyle.sectionHeaderFont)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        (NSApp.delegate as? AppDelegate)?.showSettings()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Picker("", selection: Binding(
                        get: { viewModel.viewMode },
                        set: { newMode in
                            viewModel.viewMode = newMode
                            if newMode == .folders {
                                viewModel.selectedListCategory = nil
                                viewModel.searchViewModel.clearActiveFolder()
                            }
                        }
                    )) {
                        Image(systemName: "square.grid.2x2").tag(AppViewMode.folders)
                        Image(systemName: "list.bullet").tag(AppViewMode.list)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                }
                .padding(.leading, PlatformStyle.panelPadding)
                .padding(.trailing, PlatformStyle.panelPadding / 2)

                if viewModel.viewMode == .list {
                    categoryCarousel
                        .padding(.horizontal, PlatformStyle.panelPadding)
                }

                if viewModel.viewMode == .folders {
                    CategoryGridView(
                        viewModel: viewModel.categoryViewModel,
                        onLaunchApp: { app in viewModel.launchApp(app) },
                        onExpandCategory: { category in
                            let apps = viewModel.categoryViewModel.appsForCategory(category)
                            viewModel.searchViewModel.setActiveFolder(category, apps: apps)
                        }
                    )
                    .padding(.horizontal, PlatformStyle.panelPadding)
                } else {
                    allAppsListView
                        .padding(.horizontal, PlatformStyle.panelPadding)
                }
            }
            .padding(.bottom, PlatformStyle.panelPadding)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .clipped()
        .mask(
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: 12)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 12)
            }
        )
    }

    // MARK: - Category Carousel

    private var categoryCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(viewModel.categoryViewModel.nonEmptyCategories.filter { $0 != .other }) { category in
                    categoryChip(category: category)
                }
            }
            .padding(.trailing, 4)
        }
    }

    private func categoryChip(category: AppCategory) -> some View {
        let isSelected = viewModel.selectedListCategory == category
        return Button {
            if isSelected {
                viewModel.selectedListCategory = nil
                viewModel.searchViewModel.clearActiveFolder()
            } else {
                viewModel.selectedListCategory = category
                let apps = viewModel.categoryViewModel.appsForCategory(category)
                viewModel.searchViewModel.setActiveFolder(category, apps: apps)
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: category.sfSymbol)
                    .font(.system(size: 13))
                Text(category.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.08))
            )
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
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
            onLaunch: { viewModel.launchApp(app) },
            onPin: { viewModel.pinApp(app) },
            onUnpin: { viewModel.unpinApp(app) },
            onMoveToCategory: { category in viewModel.moveAppToCategory(app, category: category) },
            onAddToDock: { viewModel.addToDock(app) },
            onCreateShortcut: { viewModel.createDesktopShortcut(app) },
            onUninstall: { viewModel.requestUninstall(app) }
        )
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
