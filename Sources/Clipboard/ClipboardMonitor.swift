import AppKit
import Combine

class ClipboardMonitor: ObservableObject {
    @Published var history: [String] = []

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private let maxItems = 10

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return }
        add(text)
    }

    func add(_ text: String) {
        // Remove duplicate if present (move to front)
        history.removeAll { $0 == text }
        history.insert(text, at: 0)

        // Cap at maxItems
        if history.count > maxItems {
            history = Array(history.prefix(maxItems))
        }
    }

    func clear() {
        history.removeAll()
    }
}
