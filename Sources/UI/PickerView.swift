import SwiftUI

// MARK: - Palette

private enum Arcade {
    static let bg       = Color(red: 0.031, green: 0.031, blue: 0.047)  // #080812
    static let pink     = Color(red: 1.0,   green: 0.125, blue: 0.471)  // #FF2078
    static let cyan     = Color(red: 0.0,   green: 0.898, blue: 1.0)    // #00E5FF
    static let yellow   = Color(red: 1.0,   green: 0.902, blue: 0.0)    // #FFE600
    static let dimText  = Color(red: 0.267, green: 0.267, blue: 0.333)  // #444455
    static let rowGlow  = Color(red: 1.0,   green: 0.125, blue: 0.471).opacity(0.08)
}

private let arcadeFont = "Courier New"

// MARK: - Layout

/// Single source of truth for picker geometry.
///
/// `PickerWindow` sizes the panel before SwiftUI lays anything out, so it has to
/// predict the content height. These constants keep that prediction and the actual
/// rendering from drifting apart — they used to be duplicated as bare numbers in
/// both files.
enum PickerLayout {
    static let width: CGFloat = 480
    static let outerPadding: CGFloat = 8

    static let headerHeight: CGFloat = 46
    static let separatorHeight: CGFloat = 5
    static let rowHeight: CGFloat = 40
    static let footerHeight: CGFloat = 28

    /// Height the content wants for `itemCount` rows, before any screen clamping.
    static func contentHeight(itemCount: Int) -> CGFloat {
        headerHeight + separatorHeight + CGFloat(itemCount) * rowHeight + footerHeight
    }
}

// MARK: - PickerView

struct PickerView: View {
    @ObservedObject var monitor: ClipboardMonitor
    @ObservedObject var state: PickerState
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

    // Blinking cursor ticker
    @State private var cursorOn = true
    private let blinker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            headerView
            separatorView
            itemsView
            footerView
        }
        .background(Arcade.bg)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Arcade.pink, lineWidth: 1.5)
        )
        // Outer neon glow
        .shadow(color: Arcade.pink.opacity(0.45), radius: 12, x: 0, y: 0)
        .shadow(color: Arcade.pink.opacity(0.2),  radius: 28, x: 0, y: 0)
        .onReceive(blinker) { _ in cursorOn.toggle() }
        .onReceive(monitor.$history) { _ in state.selectedIndex = 0 }
    }

    // MARK: Header

    private var headerView: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("👾 CLIP-9")
                .font(.custom(arcadeFont, size: 13).bold())
                .foregroundColor(Arcade.cyan)
                .tracking(3)
                // Cyan text glow
                .shadow(color: Arcade.cyan.opacity(0.8), radius: 6)

            Spacer()

            Text("\(monitor.history.count) ITEM\(monitor.history.count == 1 ? "" : "S")")
                .font(.custom(arcadeFont, size: 11).bold())
                .foregroundColor(Arcade.pink)
                .tracking(1)

            CloseButton(action: onDismiss)
                .padding(.leading, 12)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: Separator — double-stroke arcade style

    private var separatorView: some View {
        VStack(spacing: 2) {
            Rectangle().fill(Arcade.pink).frame(height: 1)
            Rectangle().fill(Arcade.pink.opacity(0.35)).frame(height: 1)
        }
        .shadow(color: Arcade.pink.opacity(0.6), radius: 4)
    }

    // MARK: Items

    private var itemsView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                // Identify rows by content, not position. History reorders on every
                // copy, and `id: \.offset` makes SwiftUI animate the wrong rows.
                // Safe because ClipboardMonitor.add() removes duplicates, so the
                // strings in `history` are unique.
                ForEach(Array(monitor.history.enumerated()), id: \.element) { index, text in
                    RowView(
                        index: index,
                        text: text,
                        isSelected: state.selectedIndex == index,
                        cursorOn: cursorOn
                    )
                    .onTapGesture {
                        state.selectedIndex = index
                        onSelect(text)
                    }
                }
            }
        }
    }

    // MARK: Footer — insert coin hint

    private var footerView: some View {
        HStack {
            Text("↑↓ MOVE")
            Text("·")
            Text("1-9 JUMP")
            Text("·")
            Text("ENTER SELECT")
            Text("·")
            Text("ESC QUIT")
        }
        .font(.custom(arcadeFont, size: 9).bold())
        .foregroundColor(Arcade.dimText)
        .tracking(1)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}

// MARK: - Close button

private struct CloseButton: View {
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text("✕")
                .font(.custom(arcadeFont, size: 12).bold())
                .foregroundColor(isHovering ? Arcade.yellow : Arcade.pink)
                .shadow(color: (isHovering ? Arcade.yellow : Arcade.pink).opacity(0.8), radius: 4)
                .frame(width: 18, height: 18)
                .overlay(
                    Rectangle()
                        .stroke(isHovering ? Arcade.yellow : Arcade.pink.opacity(0.5), lineWidth: 1)
                )
                // The panel is movable by its background, so give the button an
                // opaque hit area rather than letting clicks fall through to a drag.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Close (Esc)")
        .accessibilityLabel("Close")
    }
}

// MARK: - Row

private struct RowView: View {
    let index: Int
    let text: String
    let isSelected: Bool
    let cursorOn: Bool

    private var numberLabel: String { index < 9 ? "\(index + 1)" : "0" }

    var body: some View {
        HStack(spacing: 0) {
            // Left neon border
            Rectangle()
                .fill(isSelected ? Arcade.pink : Color.clear)
                .frame(width: 3)
                .shadow(color: isSelected ? Arcade.pink.opacity(0.9) : .clear, radius: 4)

            HStack(spacing: 0) {
                // Blinking cursor
                Text(isSelected && cursorOn ? "►" : " ")
                    .font(.custom(arcadeFont, size: 12).bold())
                    .foregroundColor(Arcade.pink)
                    .shadow(color: Arcade.pink.opacity(0.8), radius: 4)
                    .frame(width: 16, alignment: .center)

                // Number
                Text(numberLabel)
                    .font(.custom(arcadeFont, size: 12).bold())
                    .foregroundColor(isSelected ? Arcade.yellow : Arcade.dimText)
                    .frame(width: 16, alignment: .trailing)
                    .padding(.trailing, 10)

                // Content — keep original case for accurate paste preview.
                // Truncate in the middle: URLs and file paths share long prefixes,
                // so tail truncation renders similar items identically. The middle
                // keeps both the start and the distinguishing end visible.
                Text(text)
                    .font(.custom(arcadeFont, size: 12).bold())
                    .foregroundColor(isSelected ? .white : Arcade.dimText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .shadow(color: isSelected ? Color.white.opacity(0.15) : .clear, radius: 3)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
        }
        .frame(height: PickerLayout.rowHeight)
        .background(isSelected ? Arcade.rowGlow : Color.clear)
        .animation(.easeInOut(duration: 0.06), value: isSelected)
    }
}

#if DEBUG
private enum PickerViewPreviewFactory {
    static func makeMonitor(itemCount: Int = 5) -> ClipboardMonitor {
        let monitor = ClipboardMonitor()
        monitor.history = Array(sampleItems.prefix(itemCount))
        return monitor
    }

    /// Deliberately includes several long URLs that share a prefix. With tail
    /// truncation they render identically; middle truncation keeps them distinct.
    static let sampleItems = [
        "git commit -m \"Polish neon picker visuals\"",
        "https://github.com/monacotobi/clip-9/blob/main/Sources/UI/PickerView.swift",
        "https://github.com/monacotobi/clip-9/blob/main/Sources/HotKey/HotKeyManager.swift",
        "https://github.com/monacotobi/clip-9/blob/main/Sources/Clipboard/ClipboardMonitor.swift",
        "Short item",
        "Refactor selection state into shared observable object",
        "/Users/monacotobi/code/apps/clip-9/Sources/UI/PickerWindow.swift",
        "Design notes: brighter cyan highlights + softer shadows",
        "xcodebuild -project Clip-9.xcodeproj -target Clip-9 -configuration Release",
        "The last item, number ten"
    ]

    static func makeState(selectedIndex: Int) -> PickerState {
        let state = PickerState()
        state.selectedIndex = selectedIndex
        return state
    }
}

#Preview("Default") {
    PickerView(
        monitor: PickerViewPreviewFactory.makeMonitor(),
        state: PickerViewPreviewFactory.makeState(selectedIndex: 0),
        onSelect: { _ in },
        onDismiss: {}
    )
    .frame(width: PickerLayout.width)
    .padding(20)
    .background(Color.black)
}

#Preview("Selected Middle Item") {
    PickerView(
        monitor: PickerViewPreviewFactory.makeMonitor(),
        state: PickerViewPreviewFactory.makeState(selectedIndex: 2),
        onSelect: { _ in },
        onDismiss: {}
    )
    .frame(width: PickerLayout.width)
    .padding(20)
    .background(Color.black)
}

// Full history — the case that used to scroll at the old 440pt cap.
#Preview("Full history (10 items)") {
    PickerView(
        monitor: PickerViewPreviewFactory.makeMonitor(itemCount: 10),
        state: PickerViewPreviewFactory.makeState(selectedIndex: 3),
        onSelect: { _ in },
        onDismiss: {}
    )
    .frame(width: PickerLayout.width,
           height: PickerLayout.contentHeight(itemCount: 10))
    .padding(20)
    .background(Color.black)
}
#endif
