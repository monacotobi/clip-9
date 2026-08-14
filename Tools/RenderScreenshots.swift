import AppKit
import SwiftUI

// Renders the REAL SwiftUI views to PNGs for the README.
//
// Not mockups: this imports PickerView and draws it with ImageRenderer, so what ends up
// in docs/ is the same code that ships. Re-run it whenever the UI changes and the README
// can never quietly go stale.
//
//   ./Tools/render-screenshots.sh
//
// ImageRenderer draws the view, not the window, so the panel's drop shadow and rounded
// mask are reproduced here rather than captured.

@main
@MainActor
struct RenderScreenshots {

    static let scale: CGFloat = 2.0

    static func main() {
        // AppKit must exist before SwiftUI will rasterise text.
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs"
        try? FileManager.default.createDirectory(atPath: outputDir,
                                                 withIntermediateDirectories: true)

        var failures = 0
        for shot in shots {
            let ok = render(shot.view, to: "\(outputDir)/\(shot.name).png", items: shot.items)
            print(ok ? "  ✓ \(shot.name).png" : "  ✗ \(shot.name).png FAILED")
            if !ok { failures += 1 }
        }

        print(failures == 0 ? "All screenshots rendered." : "\(failures) failed.")
        exit(failures == 0 ? 0 : 1)
    }

    struct Shot {
        let name: String
        let items: Int
        let view: AnyView
    }

    /// Fixed sample data, so re-running produces identical images unless the UI changed.
    /// The long paths are deliberate: they show middle truncation doing its job.
    static let sample = [
        "git commit -m \"Fit all 10 items in the picker\"",
        "https://github.com/monacotobi/clip-9/blob/main/Sources/UI/PickerView.swift",
        "https://github.com/monacotobi/clip-9/blob/main/Sources/HotKey/HotKeyManager.swift",
        "/Users/monacotobi/code/apps/clip-9/Sources/Clipboard/ClipboardMonitor.swift",
        "Short item",
        "Refactor selection state into a shared observable object",
        "xcodebuild -project Clip-9.xcodeproj -target Clip-9 -configuration Release",
        "Design notes: brighter cyan highlights, softer shadows",
        "tobias@supergloops.com",
        "The last item, number ten",
    ]

    static var shots: [Shot] {
        [
            Shot(name: "clip-9", items: 10,
                 view: AnyView(picker(count: 10, selected: 1, isKey: true))),

            Shot(name: "clip-9-unfocused", items: 5,
                 view: AnyView(picker(count: 5, selected: 1, isKey: false))),
        ]
    }

    static func picker(count: Int, selected: Int, isKey: Bool) -> some View {
        let monitor = ClipboardMonitor()
        monitor.history = Array(sample.prefix(count))
        let state = PickerState()
        state.selectedIndex = selected
        state.isKey = isKey
        // scrollable: false — see the note on PickerView.scrollable
        return PickerView(monitor: monitor, state: state,
                          onSelect: { _ in }, onDismiss: {}, scrollable: false)
    }

    static func render(_ content: AnyView, to path: String, items: Int) -> Bool {
        // Mirrors PickerWindow: outer padding, near-black backing, rounded mask — plus a
        // backdrop so the neon glow has something to bleed onto.
        let framed = content
            .frame(width: PickerLayout.width,
                   height: PickerLayout.contentHeight(itemCount: items))
            .padding(PickerLayout.outerPadding)
            .background(Color.black.opacity(0.98))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.6), radius: 24, y: 8)
            .padding(34)
            .background(
                LinearGradient(colors: [Color(white: 0.055), Color(white: 0.015)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )

        let renderer = ImageRenderer(content: framed)
        renderer.scale = scale
        renderer.isOpaque = true

        guard let cgImage = renderer.cgImage else { return false }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        return FileManager.default.createFile(atPath: path, contents: data)
    }
}
