import SwiftUI

struct CategoryDetailView<Icon: View>: View {
    let category: AppCategory
    let apps: [AppItem]
    let appIconBuilder: (AppItem, Bool) -> Icon
    var highlightedIndex: Int? = nil

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: PlatformStyle.iconGridSpacing)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: PlatformStyle.sectionSpacing) {
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical) {
                    LazyVGrid(columns: columns, spacing: PlatformStyle.iconGridSpacing) {
                        ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                            appIconBuilder(app, index == highlightedIndex)
                                .id(app.bundleIdentifier)
                        }
                    }
                    .padding(.top, 14)
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
                .onChange(of: highlightedIndex) { _, newIndex in
                    guard let idx = newIndex, idx < apps.count else { return }
                    scrollProxy.scrollTo(apps[idx].bundleIdentifier)
                }
            }
        }
    }
}
