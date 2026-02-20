import SwiftUI

struct PinnedAppsRow: View {
    let viewModel: PinnedAppsViewModel
    let onLaunchApp: (AppItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pinned")
                .font(PlatformStyle.sectionHeaderFont)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PlatformStyle.iconGridSpacing) {
                    ForEach(viewModel.pinnedApps) { app in
                        AppIconView(
                            app: app,
                            isPinned: true,
                            onLaunch: { onLaunchApp(app) },
                            onUnpin: { viewModel.unpinApp(app) }
                        )
                    }
                }
            }
        }
    }
}
