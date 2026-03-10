import AppKit
import CoreGraphics

// CGEventTap requires a plain C-compatible function pointer — no closures.
// Use a global weak reference to bridge into the class instance.
private weak var sharedInstance: HotKeyManager?

private func tapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // If the tap was disabled by the system (e.g. slow callback), re-enable it.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = sharedInstance?.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passRetained(event)
    }

    guard type == .keyDown else { return Unmanaged.passRetained(event) }

    let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
    // Strip everything except the modifiers we care about
    let flags = event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])

    // Cmd+Shift+V only
    if keyCode == 9, flags == [.maskCommand, .maskShift] {
        DispatchQueue.main.async { sharedInstance?.fire() }
        return nil  // ← consume: prevents "Paste and Match Style" reaching the app
    }

    return Unmanaged.passRetained(event)
}

class HotKeyManager {
    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let onTrigger: () -> Void

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
        sharedInstance = self
        setup()
    }

    deinit { teardown() }

    fileprivate func fire() { onTrigger() }

    private func setup() {
        guard AXIsProcessTrusted() else {
            print("[HotKeyManager] Accessibility not granted — hotkey disabled.")
            return
        }

        let mask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue)
        )

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: tapCallback,
            userInfo: nil
        ) else {
            print("[HotKeyManager] CGEvent.tapCreate failed — check Accessibility permission.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func teardown() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        eventTap = nil
        runLoopSource = nil
    }
}
