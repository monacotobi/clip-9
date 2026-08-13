# Clip-9

A macOS menu bar app. It keeps a clipboard history and pastes an item into the previous app.
Swift 5, SwiftUI + AppKit, macOS 13+. No package manager, no dependencies, no tests.

Public repo: https://github.com/monacotobi/clip-9

## Build and verify

Xcode is required for a real build. If `xcode-select -p` points at
`/Library/Developer/CommandLineTools`, `xcodebuild` will fail and only the two gates below
are available.

**Gate 1 — project file is structurally valid:**

```sh
plutil -lint Clip-9.xcodeproj/project.pbxproj
```

**Gate 2 — all sources compile:**

```sh
swiftc -typecheck -sdk "$(xcrun --show-sdk-path)" \
       -target arm64-apple-macosx13.0 Sources/*.swift Sources/*/*.swift
```

Both pass on a clean checkout, so a failure means something just broke.

**Neither gate proves the app builds or runs.** Report a type-check as a type-check. Do not
call a change "working" or "tested" on the strength of these two alone.

A real build:

```sh
xcodebuild -project Clip-9.xcodeproj -target Clip-9 -configuration Release \
           CONFIGURATION_BUILD_DIR="$PWD/build" CODE_SIGNING_ALLOWED=NO build
```

Use `CONFIGURATION_BUILD_DIR`, not `-derivedDataPath` — xcodebuild rejects
`-derivedDataPath` unless `-scheme` is also passed, and no shared scheme is committed
(`xcuserdata/` is gitignored). CI uses this exact invocation.

Note: editors running SourceKit per-file report "cannot find X in scope" for sibling types.
That is single-file analysis without project context, not a real error. Gate 2 is
authoritative.

## Layout

| Path | Function |
|---|---|
| `Sources/Clip9App.swift` | `@main`. Empty `Settings` scene. All work is in the delegate. |
| `Sources/AppDelegate.swift` | Wires the parts together. Status bar menu. Holds `previousApp`. |
| `Sources/Clipboard/ClipboardMonitor.swift` | Polls `NSPasteboard` every 0.5 s. Keeps 10 text items. |
| `Sources/HotKey/HotKeyManager.swift` | `CGEventTap` for the global hotkey. Polls for Accessibility permission. |
| `Sources/Paste/PasteSimulator.swift` | Activates the target app and posts synthetic Cmd+V. |
| `Sources/UI/PickerWindow.swift` | Borderless `NSPanel`. Handles all key events. |
| `Sources/UI/PickerView.swift` | SwiftUI content. 80s arcade look. |

## Constraints

- **The tap callback must stay a plain C function.** `CGEvent.tapCreate` takes a C function
  pointer, not a closure. The global `private weak var sharedInstance` in `HotKeyManager.swift`
  is the bridge into the instance. Do not "clean this up" into a closure.
- **Keep the app non-sandboxed.** `Sources/Clip-9.entitlements` sets `app-sandbox` to `false`.
  A sandbox blocks the event tap and the synthetic paste.
- **Accessibility permission is required** for both the hotkey and the paste. `HotKeyManager`
  polls `AXIsProcessTrusted()` every 2 s until granted, then installs the tap. Do not move
  that check back into `AppDelegate` — an ordering bug there once left the hotkey dead until
  the app was restarted.
- **The app has no Dock icon.** `LSUIElement` is `true` and the policy is `.accessory`.
- **The picker must not steal focus.** The panel uses `.nonactivatingPanel`. If it activates
  the app, `previousApp` loses the front position and the paste goes to the wrong place.
- **Two places hold the row geometry.** `PickerWindow.show()` computes the window height from
  `46 + 5 + count * 40 + 28`. These numbers mirror the header, separator, row, and footer
  sizes in `PickerView`. Change both together.
- **The hotkey is Cmd+Option+V** (keyCode 9, `.maskCommand` + `.maskAlternate`). If you change
  it, also update the alert text in `AppDelegate.promptForAccessibility()` and the README.
- **`DEVELOPMENT_TEAM` is intentionally empty** so contributors and CI can build without a
  signing identity. Do not commit a team ID back into `project.pbxproj`.
- **`ForEach` in `PickerView` identifies rows by content**, not index. This is only safe
  because `ClipboardMonitor.add()` removes duplicates. If that dedup ever goes away, rows
  need real identity.

## Scope

The history is text only, in memory, and capped at 10 items. It does not persist.
This is deliberate and documented in the README. Ask before adding persistence, image
support, or a dependency.
