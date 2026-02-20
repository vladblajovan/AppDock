import SwiftUI

struct CategoryGridView: View {
    let viewModel: CategoryViewModel
    let onLaunchApp: (AppItem) -> Void
    var onExpandCategory: ((AppCategory) -> Void)?

    private let columns = [
        GridItem(.adaptive(minimum: 195, maximum: 220), spacing: PlatformStyle.iconGridSpacing)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: PlatformStyle.iconGridSpacing) {
            ForEach(viewModel.nonEmptyCategories) { category in
                CategoryTileView(
                    category: category,
                    previewApps: viewModel.previewApps(for: category),
                    appCount: viewModel.appsForCategory(category).count
                ) {
                    viewModel.expandCategory(category)
                    onExpandCategory?(category)
                }
            }
        }
    }
}

struct CategoryTileView: View {
    let category: AppCategory
    let previewApps: [AppItem]
    let appCount: Int
    let onTap: () -> Void

    @State private var isHovered = false

    private let previewColumns = [
        GridItem(.fixed(PlatformStyle.categoryPreviewIconSize), spacing: 6),
        GridItem(.fixed(PlatformStyle.categoryPreviewIconSize), spacing: 6),
        GridItem(.fixed(PlatformStyle.categoryPreviewIconSize), spacing: 6),
    ]

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Category name centered at top
                HStack(spacing: 5) {
                    Image(systemName: category.sfSymbol)
                        .font(.system(size: 14))
                        .foregroundStyle(category.color)

                    Text(category.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 36, alignment: .top)

                // 2x2 icon preview
                LazyVGrid(columns: previewColumns, spacing: 6) {
                    ForEach(previewApps) { app in
                        Image(nsImage: IconExtractor.shared.icon(for: app.url, size: PlatformStyle.categoryPreviewIconSize))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(
                                width: PlatformStyle.categoryPreviewIconSize,
                                height: PlatformStyle.categoryPreviewIconSize
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    // Invisible placeholders to keep grid size consistent
                    ForEach(0..<max(0, 9 - previewApps.count), id: \.self) { _ in
                        Color.clear
                            .frame(
                                width: PlatformStyle.categoryPreviewIconSize,
                                height: PlatformStyle.categoryPreviewIconSize
                            )
                    }
                }

            }
            .padding(.top, 8)
            .padding(.bottom, 10)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: PlatformStyle.categoryTileCornerRadius)
                    .fill(isHovered ? PlatformStyle.categoryTileHoverBackground : PlatformStyle.categoryTileBackground)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
