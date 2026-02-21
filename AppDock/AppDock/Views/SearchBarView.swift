import SwiftUI

struct SearchBarView: View {
    @Bindable var viewModel: SearchViewModel
    var showBackButton: Bool = false
    var showFolderChip: Bool = true
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            if showBackButton {
                Button {
                    viewModel.clearActiveFolder()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.primary.opacity(0.08))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }

            if showFolderChip, let folder = viewModel.activeFolder {
                HStack(spacing: 5) {
                    Image(systemName: folder.sfSymbol)
                        .font(.system(size: 12))
                        .foregroundStyle(folder.color)
                    Text(folder.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.1))
                )
            }

            TextField(searchPlaceholder, text: $viewModel.query)
                .font(PlatformStyle.searchFont)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit {
                    if let app = viewModel.highlightedApp {
                        viewModel.onLaunch?(app)
                    }
                }

            if viewModel.isActive {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

}
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: PlatformStyle.searchFieldCornerRadius)
                .fill(Color.primary.opacity(0.06))
        )
        .onAppear { isFocused = true }
    }

    private var searchPlaceholder: String {
        if let folder = viewModel.activeFolder {
            return showFolderChip ? "Search in folder..." : "Search in \(folder.rawValue)..."
        }
        return "Search apps..."
    }
}
