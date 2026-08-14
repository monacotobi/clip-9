#!/usr/bin/env bash
# Regenerates every app icon size from Tools/RenderIcon.swift.
set -euo pipefail
cd "$(dirname "$0")/.."
BIN="$(mktemp -d)/render-icon"
swiftc -O Tools/RenderIcon.swift -o "$BIN"
echo "Rendering app icons"
"$BIN" Sources/Assets.xcassets/AppIcon.appiconset
