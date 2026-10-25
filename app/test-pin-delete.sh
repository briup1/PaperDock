#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
CONTROLS=false
if [[ "${1:-}" == --controls ]]; then CONTROLS=true; shift; fi
if [[ $# != 2 || "$1" != /* || "$2" != /* ]]; then
    printf 'Usage: bash test-pin-delete.sh [--controls] /absolute/new-evidence-dir /absolute/new-build-dir\n' >&2; exit 64
fi
EVIDENCE="$1"; BUILD="$2"
if [[ -e "$EVIDENCE" || -e "$BUILD" ]]; then printf 'Refuse existing output; choose new directories\n' >&2; exit 64; fi
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
for suite in pin-red pin-rules pin-metadata pin-io title dates query controller palette bad-store; do run "$suite" "$EVIDENCE/data-$suite"; done
run pin-write "$EVIDENCE/pin-restart"
if [[ "$CONTROLS" == true ]]; then run pin-window-read "$EVIDENCE/pin-restart"; fi
run pin-read "$EVIDENCE/pin-restart"
run pin-read-unlocked "$EVIDENCE/pin-restart"
for suite in write read read-random; do run "$suite" "$EVIDENCE/content-restart"; done
if [[ "$CONTROLS" == true ]]; then
    # Only offscreen, self-owned controls: no edge entrance, activation, or application run loop.
    for suite in pin-controls editor hsv; do run "$suite" "$EVIDENCE/data-$suite"; done
fi
printf 'PASS focused programmatic checks; real drag/right-click/IME and full application restart are NOT verified\n'
