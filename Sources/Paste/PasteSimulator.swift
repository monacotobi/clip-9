import AppKit

enum PasteSimulator {
    /// Activates `targetApp` and posts Cmd+V key events to simulate a paste.
    static func paste(into targetApp: NSRunningApplication) {
        targetApp.activate(options: [.activateIgnoringOtherApps])

        // Small delay to let the app become frontmost before sending keystrokes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            postCmdV()
        }
    }

    private static func postCmdV() {
        let src = CGEventSource(stateID: .hidSystemState)

        // keyCode 9 = 'v'
        guard let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true),
              let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags   = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
