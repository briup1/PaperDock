#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN="$ROOT/build/PaperDock.app/Contents/MacOS/PaperDock"
if [[ ! -x "$BIN" ]]; then bash "$ROOT/build.sh"; fi
exec "$BIN" "$@"
