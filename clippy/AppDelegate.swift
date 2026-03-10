import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    let clipboardMonitor = ClipboardMonitor()
    var hotKeyManager: HotKeyManager?
    var pickerWindow: PickerWindow?
    var previousApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusBar()
        setupPickerWindow()

        hotKeyManager = HotKeyManager { [weak self] in
            self?.previousApp = NSWorkspace.shared.frontmostApplication
            self?.showPicker()
        }

        checkAccessibilityPermission()
        clipboardMonitor.start()
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clippy")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Clipboard History", action: #selector(showPickerFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let accessItem = NSMenuItem(title: "Accessibility Settings...", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        menu.addItem(accessItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Clippy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    // MARK: - Picker Window

    private func setupPickerWindow() {
        pickerWindow = PickerWindow(clipboardMonitor: clipboardMonitor) { [weak self] selectedText in
            self?.pickerWindow?.hide()
            guard let target = self?.previousApp else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(selectedText, forType: .string)
            // Brief delay to allow window to hide before pasting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                PasteSimulator.paste(into: target)
            }
        } onDismiss: { [weak self] in
            self?.pickerWindow?.hide()
        }
    }

    private func showPicker() {
        pickerWindow?.show()
    }

    @objc private func showPickerFromMenu() {
        previousApp = nil
        pickerWindow?.show()
    }

    // MARK: - Accessibility

    private func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            DispatchQueue.main.async {
                self.promptForAccessibility()
            }
        }
    }

    private func promptForAccessibility() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = "Clippy needs Accessibility access to register the global hotkey (Cmd+Shift+V) and paste into other apps.\n\nPlease enable it in System Settings > Privacy & Security > Accessibility."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
