import SwiftUI

struct CategoryDetailView<Icon: View>: View {
    let category: AppCategory
    let apps: [AppItem]
    let appIconBuilder: (AppItem) -> Icon

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: PlatformStyle.iconGridSpacing)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: PlatformStyle.sectionSpacing) {
            ScrollView(.vertical) {
                LazyVGrid(columns: columns, spacing: PlatformStyle.iconGridSpacing) {
                    ForEach(apps) { app in
                        appIconBuilder(app)
                    }
                }
                .padding(.top, 14)
                .padding(.bottom, 14)
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
    }
}
