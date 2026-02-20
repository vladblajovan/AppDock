import SwiftUI

struct PlatformStyle {
    static var isTahoe: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    // MARK: - Corner Radii

    static var panelCornerRadius: CGFloat { isTahoe ? 22 : 16 }
    static var categoryTileCornerRadius: CGFloat { isTahoe ? 16 : 12 }
    static var appIconContainerRadius: CGFloat { isTahoe ? 14 : 10 }
    static var searchFieldCornerRadius: CGFloat { isTahoe ? 12 : 8 }

    // MARK: - Spacing

    static var panelPadding: CGFloat { isTahoe ? 20 : 16 }
    static var sectionSpacing: CGFloat { isTahoe ? 16 : 12 }
    static var iconGridSpacing: CGFloat { isTahoe ? 10 : 8 }

    // MARK: - Sizes

    static var appIconSize: CGFloat { 72 }
    static var categoryPreviewIconSize: CGFloat { 46 }
    static var panelWidth: CGFloat { 900 }
    static var panelHeight: CGFloat { 640 }

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
