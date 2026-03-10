import AppKit

class HotKeyManager {
    private var monitor: Any?
    private let onTrigger: () -> Void

    // Cmd+Shift+V: keyCode 9, exactly command+shift (no other modifiers)
    private let targetKeyCode: UInt16 = 9
    private let requiredFlags: NSEvent.ModifierFlags = [.command, .shift]
    private let excludedFlags: NSEvent.ModifierFlags = [.option, .control, .function]

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
        setup()
    }

    deinit {
        if let m = monitor { NSEvent.removeMonitor(m) }
    }

    private func setup() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard event.keyCode == self.targetKeyCode,
                  flags.contains(self.requiredFlags),
                  flags.isDisjoint(with: self.excludedFlags)
            else { return }

            DispatchQueue.main.async { self.onTrigger() }
        }

        if monitor == nil {
            print("[HotKeyManager] Could not register global monitor — check Accessibility permission.")
        }
    }
}
