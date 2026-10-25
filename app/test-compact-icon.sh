#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
if [[ $# != 2 || "$1" != /* || "$2" != /* ]]; then
    printf 'Usage: bash test-compact-icon.sh /absolute/new-evidence-dir /absolute/new-build-dir\n' >&2; exit 64
fi
EVIDENCE="$1"; BUILD="$2"
if [[ -e "$EVIDENCE" || -e "$BUILD" ]]; then printf 'Refuse existing outputs; choose new directories\n' >&2; exit 64; fi
mkdir -p "$EVIDENCE"
exec > >(tee "$EVIDENCE/commands.log") 2>&1
bash "$ROOT/build.sh" "$BUILD"
BIN="$BUILD/PaperDock.app/Contents/MacOS/PaperDock"
run() {
    local suite="$1" data="$2" status=0
    printf 'RUN: %q --test %q --data-dir %q\n' "$BIN" "$suite" "$data"
    "$BIN" --test "$suite" --data-dir "$data" > "$EVIDENCE/$suite.log" 2>&1 || status=$?
    printf '%s EXIT=%s\n' "$suite" "$status"
    return "$status"
}
for suite in compact-red compact-controls pin-rules pin-metadata pin-controls editor; do run "$suite" "$EVIDENCE/data-$suite"; done
for suite in compact-write compact-read; do run "$suite" "$EVIDENCE/small-restart"; done
for suite in pin-write pin-window-read pin-read pin-read-unlocked; do run "$suite" "$EVIDENCE/legacy-frame-restart"; done
ICON="$BUILD/PaperDock.app/Contents/Resources/PaperDock.icns"
DECLARED=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$BUILD/PaperDock.app/Contents/Info.plist")
[[ "$DECLARED" == PaperDock.icns ]]
cmp "$ROOT/../assets/brand/PaperDock.icns" "$ICON"
shasum -a 256 "$ROOT/../assets/brand/PaperDock.icns" "$ICON" > "$EVIDENCE/icon-hashes.txt"
iconutil --convert iconset "$ICON" --output "$EVIDENCE/unpacked.iconset"
for size in 16 32 1024; do
    if [[ "$size" == 1024 ]]; then name=icon_512x512@2x.png; else name="icon_${size}x${size}.png"; fi
    sips -g pixelWidth -g pixelHeight "$EVIDENCE/unpacked.iconset/$name"
done
# The R1 gate must reject exit=0 plus normal-save marker without an actual completed GUI result.
mkdir -p "$EVIDENCE/runner-negative/gui"
printf 'normal termination\n' > "$EVIDENCE/runner-negative/gui/normal-exit.txt"
status=0
bash "$ROOT/test.sh" --check-gui-result "$EVIDENCE/runner-negative" 2147483000 0 > "$EVIDENCE/runner-negative/gate.log" 2>&1 || status=$?
printf 'R1 missing-result EXIT=%s (expected 1)\n' "$status"
[[ "$status" == 1 ]]
printf 'PASS focused programmatic controls/frame/icon bundle checks; no complete GUI, physical input, Dock or system screenshots verified\n'
