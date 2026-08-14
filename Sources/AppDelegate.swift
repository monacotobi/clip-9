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
            // Three stacked bars — the same shape as the app icon, so the menu bar and
            // Finder read as the same app.
            //
            // Deliberately a template image (monochrome, tinted by macOS) rather than the
            // colour icon: menu bar extras have to stay legible on a light menu bar, a
            // dark one, and translucent over any wallpaper. A dark squircle would be a
            // blob in light mode.
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .bold)
            let image = NSImage(systemSymbolName: "line.3.horizontal",
                                accessibilityDescription: "Clip-9")?
                .withSymbolConfiguration(config)
            image?.isTemplate = true
            button.image = image
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Clipboard History", action: #selector(showPickerFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let accessItem = NSMenuItem(title: "Accessibility Settings...", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        menu.addItem(accessItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Clip-9", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    // MARK: - Picker Window

    private func setupPickerWindow() {
        pickerWindow = PickerWindow(clipboardMonitor: clipboardMonitor) { [weak self] selectedText in
            guard let self else { return }
            self.pickerWindow?.hide()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(selectedText, forType: .string)

            // Use the app that was frontmost before picker opened,
            // or skip paste simulation if opened from menu bar
            guard let target = self.previousApp else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
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
        alert.informativeText = "Clip-9 needs Accessibility access to register the global hotkey (Cmd+Option+V) and paste into other apps.\n\nPlease enable it in System Settings > Privacy & Security > Accessibility.\n\nThe hotkey starts working as soon as you grant access. No restart needed."
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
