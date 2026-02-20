import SwiftUI

struct SearchBarView: View {
    @Bindable var viewModel: SearchViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)

            if let folder = viewModel.activeFolder {
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

            TextField(viewModel.activeFolder != nil ? "Search in folder..." : "Search apps...", text: $viewModel.query)
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
}
