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

    // Cmd+Option+V only
    if keyCode == 9, flags == [.maskCommand, .maskAlternate] {
        DispatchQueue.main.async { sharedInstance?.fire() }
        return nil  // ← consume the event
    }

    return Unmanaged.passRetained(event)
}

class HotKeyManager {
    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionTimer: Timer?
    private let onTrigger: () -> Void

    /// How often to re-check for Accessibility permission while it is missing.
    private let permissionPollInterval: TimeInterval = 2.0

    /// True once the event tap is installed and listening for the hotkey.
    var isActive: Bool { eventTap != nil }

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
        sharedInstance = self
        setup()
    }

    deinit { teardown() }

    fileprivate func fire() { onTrigger() }

    private func setup() {
        guard AXIsProcessTrusted() else {
            // The user can grant Accessibility while the app is running. Poll for
            // it instead of silently giving up, which would leave the hotkey dead
            // until the next launch.
            print("[HotKeyManager] Accessibility not granted — waiting for permission.")
            startPermissionPolling()
            return
        }

        installTap()
    }

    // MARK: - Permission polling

    private func startPermissionPolling() {
        guard permissionTimer == nil else { return }

        let timer = Timer(timeInterval: permissionPollInterval, repeats: true) { [weak self] _ in
            guard let self, AXIsProcessTrusted() else { return }
            self.installTap()
            // Stop only once the tap is really installed. tapCreate can still fail
            // after the permission check passes; keep retrying if it does.
            if self.isActive { self.stopPermissionPolling() }
        }
        permissionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    // MARK: - Event tap

    private func installTap() {
        guard eventTap == nil else { return }

        let mask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue) |
            (1 << CGEventType.tapDisabledByUserInput.rawValue)
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
        print("[HotKeyManager] Hotkey active — Cmd+Option+V.")
    }

    private func teardown() {
        stopPermissionPolling()
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        eventTap = nil
        runLoopSource = nil
    }
}
