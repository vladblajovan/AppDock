import SwiftUI

struct PinnedAppsRow: View {
    let viewModel: PinnedAppsViewModel
    let onLaunchApp: (AppItem) -> Void
    var extraHorizontalPadding: CGFloat = 0
    var gridColumns: [GridItem]?
    var gridSpacing: CGFloat?

    @AppStorage("showPinnedAppNames") private var showPinnedAppNames: Bool = false
    @State private var draggingApp: AppItem?
    @State private var dragOffset: CGSize = .zero
    @State private var itemFrames: [String: CGRect] = [:]

    private static let defaultColumns = [GridItem(.adaptive(minimum: PlatformStyle.appIconSize + 4), spacing: 4)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pinned")
                .font(PlatformStyle.subsectionHeaderFont)
                .foregroundStyle(.secondary)
                .padding(.horizontal, extraHorizontalPadding)

            LazyVGrid(columns: gridColumns ?? Self.defaultColumns, spacing: gridSpacing ?? 4) {
                ForEach(viewModel.pinnedApps) { app in
                    AppIconView(
                        app: app,
                        isPinned: true,
                        showLabel: showPinnedAppNames,
                        onLaunch: { onLaunchApp(app) },
                        onUnpin: { viewModel.unpinApp(app) }
                    )
                    .opacity(draggingApp == app ? 0.5 : 1)
                    .scaleEffect(draggingApp == app ? 1.05 : 1)
                    .fixedSize(horizontal: draggingApp == app, vertical: false)
                    .offset(draggingApp == app ? dragOffset : .zero)
                    .zIndex(draggingApp == app ? 1 : 0)
                    .background(GeometryReader { geo in
                        Color.clear.preference(
                            key: FramePreferenceKey.self,
                            value: [app.bundleIdentifier: geo.frame(in: .named("pinnedGrid"))]
                        )
                    })
                    .gesture(
                        LongPressGesture(minimumDuration: 0.2)
                            .sequenced(before: DragGesture(coordinateSpace: .named("pinnedGrid")))
                            .onChanged { value in
                                switch value {
                                case .second(true, let drag):
                                    if draggingApp == nil {
                                        draggingApp = app
                                    }
                                    if let drag {
                                        dragOffset = drag.translation
                                        let dragLocation = drag.location
                                        checkForReorder(dragLocation: dragLocation, currentApp: app)
                                    }
                                default:
                                    break
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    draggingApp = nil
                                    dragOffset = .zero
                                }
                            }
                    )
                }
            }
            .coordinateSpace(name: "pinnedGrid")
            .onPreferenceChange(FramePreferenceKey.self) { frames in
                itemFrames = frames
            }
            .padding(.horizontal, extraHorizontalPadding)
        }
    }

    private func checkForReorder(dragLocation: CGPoint, currentApp: AppItem) {
        for (bundleID, frame) in itemFrames {
            guard bundleID != currentApp.bundleIdentifier,
                  frame.contains(dragLocation),
                  let fromIndex = viewModel.pinnedApps.firstIndex(where: { $0.bundleIdentifier == currentApp.bundleIdentifier }),
                  let toIndex = viewModel.pinnedApps.firstIndex(where: { $0.bundleIdentifier == bundleID })
            else { continue }

            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.movePinnedApp(from: IndexSet(integer: fromIndex), to: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
            break
        }
    }
}

private struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
