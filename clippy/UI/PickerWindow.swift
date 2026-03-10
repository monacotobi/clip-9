import AppKit
import SwiftUI

class PickerWindow: NSPanel {
    private let clipboardMonitor: ClipboardMonitor
    private let onSelect: (String) -> Void
    private let onDismiss: () -> Void
    private var hostingView: NSHostingView<PickerView>?

    init(clipboardMonitor: ClipboardMonitor, onSelect: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
        self.clipboardMonitor = clipboardMonitor
        self.onSelect = onSelect
        self.onDismiss = onDismiss

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 60),
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

    private func setupContent() {
        let pickerView = PickerView(
            monitor: clipboardMonitor,
            onSelect: { [weak self] text in
                self?.onSelect(text)
            },
            onDismiss: { [weak self] in
                self?.onDismiss()
            }
        )

        let hosting = NSHostingView(rootView: pickerView)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting
        hostingView = hosting
    }

    func show() {
        guard !clipboardMonitor.history.isEmpty else { return }

        // Center on screen
        if let screen = NSScreen.main {
            let sw = screen.visibleFrame.width
            let sh = screen.visibleFrame.height
            let ox = screen.visibleFrame.origin.x
            let oy = screen.visibleFrame.origin.y
            let ww: CGFloat = 480
            let wh: CGFloat = min(CGFloat(44 + clipboardMonitor.history.count * 44), 420)
            setFrame(NSRect(x: ox + (sw - ww) / 2, y: oy + (sh - wh) / 2, width: ww, height: wh), display: false)
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

    // Forward Esc to dismiss
    override func cancelOperation(_ sender: Any?) {
        onDismiss()
    }
}
