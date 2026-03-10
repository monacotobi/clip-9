import SwiftUI
import AppKit

// MARK: - Colors

private extension Color {
    static let clippyBg       = Color(red: 0.039, green: 0.059, blue: 0.039) // #0A0F0A
    static let clippyAccent   = Color(red: 0.0,   green: 1.0,   blue: 0.533) // #00FF88
    static let clippyDim      = Color(hex: "#888888")
    static let clippyBorder   = Color(red: 0.15,  green: 0.22,  blue: 0.15)
}

private extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}

// MARK: - PickerView

struct PickerView: View {
    @ObservedObject var monitor: ClipboardMonitor
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

    @State private var selectedIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("◈  CLIPBOARD")
                    .font(.custom("SF Mono", size: 11).weight(.semibold))
                    .foregroundColor(.clippyAccent)
                    .tracking(2)
                Spacer()
                Text("\(monitor.history.count) item\(monitor.history.count == 1 ? "" : "s")")
                    .font(.custom("SF Mono", size: 11))
                    .foregroundColor(.clippyDim)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()
                .background(Color.clippyBorder)

            // Items
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(monitor.history.enumerated()), id: \.offset) { index, text in
                        RowView(
                            index: index,
                            text: text,
                            isSelected: selectedIndex == index
                        )
                        .onTapGesture {
                            selectedIndex = index
                            confirmSelection()
                        }
                    }
                }
            }
        }
        .background(Color.clippyBg)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.clippyBorder, lineWidth: 1)
        )
        // Keyboard handling via NSHostingView wrapper
        .background(KeyboardHandlerView(
            onUp: { selectedIndex = max(0, selectedIndex - 1) },
            onDown: { selectedIndex = min(monitor.history.count - 1, selectedIndex + 1) },
            onNumber: { n in
                let idx = n == 0 ? 9 : n - 1
                if idx < monitor.history.count { selectedIndex = idx }
            },
            onEnter: { confirmSelection() },
            onEscape: { onDismiss() }
        ))
        .onReceive(monitor.$history) { _ in
            selectedIndex = 0
        }
    }

    private func confirmSelection() {
        guard selectedIndex < monitor.history.count else { return }
        onSelect(monitor.history[selectedIndex])
    }
}

// MARK: - Row

private struct RowView: View {
    let index: Int
    let text: String
    let isSelected: Bool

    private var label: String {
        index < 9 ? "\(index + 1)" : "0"
    }

    var body: some View {
        HStack(spacing: 0) {
            // Green left border when selected
            Rectangle()
                .fill(isSelected ? Color.clippyAccent : Color.clear)
                .frame(width: 3)

            HStack(spacing: 10) {
                Text(label)
                    .font(.custom("SF Mono", size: 13))
                    .foregroundColor(isSelected ? Color.clippyAccent : Color.clippyDim)
                    .frame(width: 14, alignment: .trailing)

                Text(isSelected ? "▶" : " ")
                    .font(.custom("SF Mono", size: 13))
                    .foregroundColor(Color.clippyAccent)
                    .frame(width: 14)

                Text(text)
                    .font(.custom("SF Mono", size: 13))
                    .foregroundColor(isSelected ? .white : Color.clippyDim)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(height: 44)
        .background(
            isSelected
                ? Color.clippyAccent.opacity(0.07)
                : Color.clear
        )
        .animation(.easeInOut(duration: 0.08), value: isSelected)
    }
}

// MARK: - Keyboard Handler (NSViewRepresentable bridge)

private struct KeyboardHandlerView: NSViewRepresentable {
    let onUp: () -> Void
    let onDown: () -> Void
    let onNumber: (Int) -> Void
    let onEnter: () -> Void
    let onEscape: () -> Void

    func makeNSView(context: Context) -> KeyCapture {
        let v = KeyCapture()
        v.onUp = onUp
        v.onDown = onDown
        v.onNumber = onNumber
        v.onEnter = onEnter
        v.onEscape = onEscape
        return v
    }

    func updateNSView(_ nsView: KeyCapture, context: Context) {
        nsView.onUp = onUp
        nsView.onDown = onDown
        nsView.onNumber = onNumber
        nsView.onEnter = onEnter
        nsView.onEscape = onEscape
    }
}

class KeyCapture: NSView {
    var onUp: (() -> Void)?
    var onDown: (() -> Void)?
    var onNumber: ((Int) -> Void)?
    var onEnter: (() -> Void)?
    var onEscape: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126: onUp?()     // Up arrow
        case 125: onDown?()   // Down arrow
        case 36, 76: onEnter?() // Return, Enter
        case 53: onEscape?()  // Escape
        default:
            // Number keys 1-9 (keyCode 18-26), 0 (keyCode 29)
            if let num = numberFromKeyCode(event.keyCode) {
                onNumber?(num)
            } else {
                super.keyDown(with: event)
            }
        }
    }

    private func numberFromKeyCode(_ keyCode: UInt16) -> Int? {
        switch keyCode {
        case 18: return 1
        case 19: return 2
        case 20: return 3
        case 21: return 4
        case 23: return 5
        case 22: return 6
        case 26: return 7
        case 28: return 8
        case 25: return 9
        case 29: return 0
        default: return nil
        }
    }
}
