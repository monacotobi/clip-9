#!/usr/bin/env bash
# Renders the real SwiftUI views to docs/*.png. See Tools/RenderScreenshots.swift.
set -euo pipefail
cd "$(dirname "$0")/.."

BIN="$(mktemp -d)/render-screenshots"

swiftc -O \
  Sources/Clipboard/ClipboardMonitor.swift \
  Sources/UI/PickerWindow.swift \
  Sources/UI/PickerView.swift \
  Tools/RenderScreenshots.swift \
  -o "$BIN"

echo "Rendering screenshots into docs/"
"$BIN" docs
