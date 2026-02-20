import SwiftUI
import Carbon.HIToolbox

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

            HotkeyBadgeView()
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
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

private struct HotkeyBadgeView: View {
    @AppStorage("hotkeyKeyCode") private var keyCode: Int = -1
    @AppStorage("hotkeyModifiers") private var modifiers: Int = 0

    var body: some View {
        if keyCode >= 0 {
            Text(displayString)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.06))
                )
        }
    }

    private var displayString: String {
        let flags = CGEventFlags(rawValue: UInt64(modifiers))
        var parts: [String] = []
        if flags.contains(.maskControl) { parts.append("⌃") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskShift) { parts.append("⇧") }
        if flags.contains(.maskCommand) { parts.append("⌘") }
        parts.append(keyName)
        return parts.joined()
    }

    private var keyName: String {
        let knownKeys: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "Return", kVK_Tab: "Tab",
            kVK_Delete: "Delete", kVK_Escape: "Esc",
            kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_LeftArrow: "←", kVK_RightArrow: "→",
        ]
        if let name = knownKeys[keyCode] { return name }

        if let currentKeyboard = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
           let layoutDataPtr = TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData) {
            let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPtr).takeUnretainedValue() as Data
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length: Int = 0
            layoutData.withUnsafeBytes { rawBuf in
                let layoutPtr = rawBuf.bindMemory(to: UCKeyboardLayout.self).baseAddress!
                UCKeyTranslate(layoutPtr, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                               UInt32(LMGetKbdType()), UInt32(kUCKeyTranslateNoDeadKeysBit),
                               &deadKeyState, chars.count, &length, &chars)
            }
            if length > 0 { return String(utf16CodeUnits: chars, count: length).uppercased() }
        }
        return "Key\(keyCode)"
    }
}
