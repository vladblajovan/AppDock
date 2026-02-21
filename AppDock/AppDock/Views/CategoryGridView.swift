import SwiftUI

struct CategoryGridView: View {
    let viewModel: CategoryViewModel
    let onLaunchApp: (AppItem) -> Void
    var onExpandCategory: ((AppCategory) -> Void)?
    var hasNewOrUpdatedApps: ((AppCategory) -> Bool)?
    var aggregateBadgeCount: ((AppCategory) -> Int)?
    var highlightedIndex: Int? = nil
    var suppressHover: Bool = false
    var onHoverChanged: ((Bool) -> Void)?

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 240), spacing: PlatformStyle.categoryGridSpacing)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: PlatformStyle.categoryGridSpacing) {
            ForEach(Array(viewModel.nonEmptyCategories.enumerated()), id: \.element) { index, category in
                CategoryTileView(
                    category: category,
                    previewApps: viewModel.previewApps(for: category),
                    appCount: viewModel.appsForCategory(category).count,
                    hasNewOrUpdatedApps: hasNewOrUpdatedApps?(category) ?? false,
                    aggregateBadgeCount: aggregateBadgeCount?(category) ?? 0,
                    isHighlighted: index == highlightedIndex,
                    suppressHover: suppressHover,
                    onHoverChanged: onHoverChanged
                ) {
                    viewModel.expandCategory(category)
                    onExpandCategory?(category)
                }
                .id("main-\(index)")
            }
        }
    }
}

struct CategoryTileView: View {
    let category: AppCategory
    let previewApps: [AppItem]
    let appCount: Int
    var hasNewOrUpdatedApps: Bool = false
    var aggregateBadgeCount: Int = 0
    var isHighlighted: Bool = false
    var suppressHover: Bool = false
    var onHoverChanged: ((Bool) -> Void)?
    let onTap: () -> Void

    @State private var isHovered = false

    private let iconSpacing: CGFloat = 6
    private let titleHeight: CGFloat = 20
    private let titleGap: CGFloat = 12

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: titleGap) {
                // Title row
                HStack(spacing: 5) {
                    Image(systemName: category.sfSymbol)
                        .font(.system(size: 14))
                        .foregroundStyle(category.color)

                    Text(category.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .frame(height: titleHeight)

                // Square 3×3 grid area
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        GeometryReader { geo in
                            let size = geo.size.width
                            let iconSize = max(0, (size - iconSpacing * 2) / 3)

                            VStack(spacing: iconSpacing) {
                                ForEach(0..<3, id: \.self) { row in
                                    HStack(spacing: iconSpacing) {
                                        ForEach(0..<3, id: \.self) { col in
                                            let index = row * 3 + col
                                            if index < previewApps.count {
                                                Image(nsImage: IconExtractor.shared.icon(for: previewApps[index].url, size: 56, bundleIdentifier: previewApps[index].bundleIdentifier))
                                                    .resizable()
                                                    .aspectRatio(1, contentMode: .fit)
                                                    .frame(width: iconSize, height: iconSize)
                                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                            } else {
                                                Color.clear
                                                    .frame(width: iconSize, height: iconSize)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
            }
            .padding(PlatformStyle.tilePaddingH)
            .background(
                RoundedRectangle(cornerRadius: PlatformStyle.categoryTileCornerRadius)
                    .fill(((isHovered && !suppressHover) || isHighlighted) ? PlatformStyle.categoryTileHoverBackground : PlatformStyle.categoryTileBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: PlatformStyle.categoryTileCornerRadius))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if aggregateBadgeCount > 0 {
                BadgeLabelView(count: aggregateBadgeCount)
                    .offset(x: 11, y: -11)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
            onHoverChanged?(hovering)
        }
    }
}
