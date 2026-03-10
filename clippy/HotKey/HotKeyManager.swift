import AppKit
import Carbon

class HotKeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let onTrigger: () -> Void

    // Cmd+Shift+V: keyCode 9, flags: command + shift
    private let targetKeyCode: CGKeyCode = 9
    private let targetFlags: CGEventFlags = [.maskCommand, .maskShift]

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
        setupEventTap()
    }

    deinit {
        teardown()
    }

    private func setupEventTap() {
        guard AXIsProcessTrusted() else {
            print("[HotKeyManager] Accessibility not granted — hotkey disabled.")
            return
        }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        // We need a way to pass self into the C callback. Use an unretained pointer.
        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userInfo).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            print("[HotKeyManager] Failed to create event tap.")
            Unmanaged<HotKeyManager>.fromOpaque(selfPtr).release()
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])

        if keyCode == targetKeyCode && flags == targetFlags {
            DispatchQueue.main.async { [weak self] in
                self?.onTrigger()
            }
            // Consume the event
            return nil
        }

        return Unmanaged.passRetained(event)
    }

    private func teardown() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
    }
}
