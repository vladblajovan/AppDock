import SwiftUI

struct CategoryDetailView<Icon: View>: View {
    let category: AppCategory
    let apps: [AppItem]
    let onBack: () -> Void
    let appIconBuilder: (AppItem) -> Icon

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: PlatformStyle.iconGridSpacing)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: PlatformStyle.sectionSpacing) {
            // Header with back button
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 7) {
                    Image(systemName: category.sfSymbol)
                        .font(.system(size: 18))
                        .foregroundStyle(category.color)
                    Text(category.rawValue)
                        .font(.system(size: 18, weight: .semibold))
                }

                Spacer()

                Text("\(apps.count) apps")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

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
