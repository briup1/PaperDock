#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$ROOT/build}"
case "$OUT" in /*) ;; *) printf 'build output must be absolute\n' >&2; exit 64;; esac
mkdir -p "$OUT/PaperDock.app/Contents/MacOS" "$OUT/PaperDock.app/Contents/Resources"
cp "$ROOT/../assets/brand/PaperDock.icns" "$OUT/PaperDock.app/Contents/Resources/PaperDock.icns"
swiftc -swift-version 5 -O -framework AppKit -framework SwiftUI -framework CoreData "$ROOT"/Sources/*.swift -o "$OUT/PaperDock.app/Contents/MacOS/PaperDock"
/usr/libexec/PlistBuddy -c Clear -c 'Add :CFBundleExecutable string PaperDock' -c 'Add :CFBundleIdentifier string local.paperdock.app' -c 'Add :CFBundleName string PaperDock' -c 'Add :CFBundleIconFile string PaperDock.icns' -c 'Add :CFBundlePackageType string APPL' -c 'Add :CFBundleShortVersionString string 0.1.1' -c 'Add :CFBundleVersion string 2' -c 'Add :NSHighResolutionCapable bool true' -c 'Add :LSMinimumSystemVersion string 26.0' "$OUT/PaperDock.app/Contents/Info.plist" >/dev/null
printf '%s\n' "$OUT/PaperDock.app/Contents/MacOS/PaperDock"
