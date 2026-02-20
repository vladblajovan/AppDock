import SwiftUI

struct PlatformStyle {
    static var isTahoe: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    // MARK: - Corner Radii

    static var panelCornerRadius: CGFloat { isTahoe ? 22 : 16 }
    static var categoryTileCornerRadius: CGFloat { isTahoe ? 22 : 16 }
    static var appIconContainerRadius: CGFloat { isTahoe ? 14 : 10 }
    static var searchFieldCornerRadius: CGFloat { isTahoe ? 22 : 16 }

    // MARK: - Spacing

    static var panelPadding: CGFloat { isTahoe ? 20 : 16 }
    static var sectionSpacing: CGFloat { isTahoe ? 16 : 12 }
    static var iconGridSpacing: CGFloat { isTahoe ? 10 : 8 }

    // MARK: - Sizes

    static var appIconSize: CGFloat { 72 }
    static var categoryPreviewIconSize: CGFloat { 38 }
    static var panelMinWidth: CGFloat { 600 }
    static var panelMaxWidth: CGFloat { 1400 }
    static var panelDefaultWidth: CGFloat { 900 }
    static var panelHeight: CGFloat { 640 }

    // MARK: - Tile Layout

    static var tilePaddingH: CGFloat { 12 }
    static var tilePaddingTop: CGFloat { 10 }
    static var tilePaddingBottom: CGFloat { 12 }
    static var tileInternalSpacing: CGFloat { 8 }

    /// Fixed height for all category tiles: top padding + title + gap + 3 rows of icons + bottom padding
    static var categoryTileHeight: CGFloat {
        // tilePaddingTop(10) + title(20) + gap(4) + 3 icon rows(46×3 + 6×2 = 150) + tilePaddingBottom(12) = 196
        tilePaddingTop + 20 + 4 + (categoryPreviewIconSize * 3 + 6 * 2) + tilePaddingBottom
    }

    // MARK: - Typography

    static var sectionHeaderFont: Font { .system(size: 18, weight: .semibold) }
    static var appLabelFont: Font { .system(size: 12) }
    static var searchFont: Font { .system(size: 18) }

    // MARK: - Materials & Effects

    static var categoryTileBackground: AnyShapeStyle {
        AnyShapeStyle(Color.primary.opacity(0.08))
    }

    static var categoryTileHoverBackground: AnyShapeStyle {
        AnyShapeStyle(Color.primary.opacity(0.15))
    }

    // MARK: - Theme

    static var sequoiaMaterial: NSVisualEffectView.Material {
        .hudWindow
    }

    static func sequoiaMaterial(for colorScheme: ColorScheme) -> NSVisualEffectView.Material {
        colorScheme == .dark ? .hudWindow : .headerView
    }
}
