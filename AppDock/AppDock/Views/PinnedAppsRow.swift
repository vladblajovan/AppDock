import SwiftUI

struct PinnedAppsRow: View {
    let viewModel: PinnedAppsViewModel
    let onLaunchApp: (AppItem) -> Void
    var extraHorizontalPadding: CGFloat = 0
    var gridColumns: [GridItem]?
    var gridSpacing: CGFloat?
    var highlightedIndex: Int? = nil
    var suppressHover: Bool = false
    var onHoverChanged: ((Bool) -> Void)?

    @AppStorage("showPinnedAppNames") private var showPinnedAppNames: Bool = false
    @State private var draggingApp: AppItem?
    @State private var dragOffset: CGSize = .zero
    @State private var dragBaseOffset: CGSize = .zero
    @State private var itemFrames: [String: CGRect] = [:]

    private static let defaultColumns = [GridItem(.adaptive(minimum: PlatformStyle.appIconSize + 20), spacing: PlatformStyle.iconGridSpacing)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pinned")
                .font(PlatformStyle.subsectionHeaderFont)
                .foregroundStyle(.secondary)
                .padding(.horizontal, extraHorizontalPadding)

            LazyVGrid(columns: gridColumns ?? Self.defaultColumns, spacing: gridSpacing ?? PlatformStyle.iconGridSpacing) {
                ForEach(Array(viewModel.pinnedApps.enumerated()), id: \.element.id) { index, app in
                    AppIconView(
                        app: app,
                        isPinned: true,
                        showLabel: showPinnedAppNames,
                        isHighlighted: index == highlightedIndex,
                        suppressHover: suppressHover,
                        onLaunch: { onLaunchApp(app) },
                        onUnpin: { viewModel.unpinApp(app) },
                        onHoverChanged: onHoverChanged
                    )
                    .opacity(draggingApp == app ? 0.5 : 1)
                    .scaleEffect(draggingApp == app ? 1.05 : 1)
                    .fixedSize(horizontal: draggingApp == app, vertical: false)
                    .offset(draggingApp == app ? dragOffset : .zero)
                    .zIndex(draggingApp == app ? 1 : 0)
                    .id("pinned-\(app.bundleIdentifier)")
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
                                        dragBaseOffset = .zero
                                    }
                                    if let drag {
                                        dragOffset = CGSize(
                                            width: drag.translation.width + dragBaseOffset.width,
                                            height: drag.translation.height + dragBaseOffset.height
                                        )
                                        checkForReorder(dragLocation: drag.location, currentApp: app)
                                    }
                                default:
                                    break
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.easeOut(duration: 0.08)) {
                                    draggingApp = nil
                                    dragOffset = .zero
                                    dragBaseOffset = .zero
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
        guard let currentFrame = itemFrames[currentApp.bundleIdentifier] else { return }
        for (bundleID, frame) in itemFrames {
            guard bundleID != currentApp.bundleIdentifier,
                  frame.contains(dragLocation),
                  let fromIndex = viewModel.pinnedApps.firstIndex(where: { $0.bundleIdentifier == currentApp.bundleIdentifier }),
                  let toIndex = viewModel.pinnedApps.firstIndex(where: { $0.bundleIdentifier == bundleID })
            else { continue }

            // Adjust base offset so the item stays under the cursor after the swap
            let targetFrame = frame
            dragBaseOffset = CGSize(
                width: dragBaseOffset.width + (currentFrame.midX - targetFrame.midX),
                height: dragBaseOffset.height + (currentFrame.midY - targetFrame.midY)
            )

            withAnimation(.easeOut(duration: 0.08)) {
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
