import AppKit
import SwiftUI

// Shared state between NSPanel (key events) and SwiftUI (rendering)
class PickerState: ObservableObject {
    @Published var selectedIndex: Int = 0
}

class PickerWindow: NSPanel {
    let pickerState = PickerState()
    private let clipboardMonitor: ClipboardMonitor
    private let onSelect: (String) -> Void
    private let onDismiss: () -> Void
    private let pickerWidth = PickerLayout.width
    private let outerPadding = PickerLayout.outerPadding

    init(
        clipboardMonitor: ClipboardMonitor,
        onSelect: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.clipboardMonitor = clipboardMonitor
        self.onSelect = onSelect
        self.onDismiss = onDismiss

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: pickerWidth + outerPadding * 2, height: 60),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        alphaValue = 0

        setupContent()
    }

    // NSPanel can become key without activating the app
    override var canBecomeKey: Bool { true }

    private func setupContent() {
        let view = PickerView(
            monitor: clipboardMonitor,
            state: pickerState,
            onSelect: { [weak self] text in self?.onSelect(text) },
            onDismiss: { [weak self] in self?.onDismiss() }
        )
        .padding(outerPadding)
        .background(Color.black.opacity(0.98))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        contentView = NSHostingView(rootView: view)
    }

    // MARK: - Show / Hide

    func show() {
        guard !clipboardMonitor.history.isEmpty else { return }
        pickerState.selectedIndex = 0

        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            let ww: CGFloat = pickerWidth + outerPadding * 2
            // Show every item. The only limit is the screen itself — if the history
            // ever outgrows it, the ScrollView in PickerView takes over.
            let wanted = PickerLayout.contentHeight(itemCount: clipboardMonitor.history.count)
            let maxHeight = sf.height - outerPadding * 2 - 40
            let contentHeight = min(wanted, maxHeight)
            let wh: CGFloat = contentHeight + outerPadding * 2
            setFrame(NSRect(
                x: sf.origin.x + (sf.width - ww) / 2,
                y: sf.origin.y + (sf.height - wh) / 2,
                width: ww, height: wh
            ), display: false)
        }

        makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            animator().alphaValue = 1.0
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        let count = clipboardMonitor.history.count
        switch event.keyCode {
        case 126: // Up arrow
            pickerState.selectedIndex = max(0, pickerState.selectedIndex - 1)
        case 125: // Down arrow
            pickerState.selectedIndex = min(count - 1, pickerState.selectedIndex + 1)
        case 36, 76: // Return / numpad Enter
            confirmSelection()
        case 53: // Escape
            onDismiss()
        default:
            if let n = numberFromKeyCode(event.keyCode) {
                let idx = n == 0 ? 9 : n - 1
                if idx < count { pickerState.selectedIndex = idx }
            }
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onDismiss()
    }

    private func confirmSelection() {
        guard pickerState.selectedIndex < clipboardMonitor.history.count else { return }
        onSelect(clipboardMonitor.history[pickerState.selectedIndex])
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
