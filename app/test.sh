#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
check_gui_result() {
    local evidence="$1" pid="$2" status="$3"
    if [[ "$status" != 0 ]]; then printf 'FAIL: GUI EXIT=%s\n' "$status"; return 1; fi
    if ps -p "$pid" -o pid=,lstart=,command=; then printf 'FAIL: GUI PID still alive\n'; return 1; fi
    if [[ ! -f "$evidence/gui/normal-exit.txt" || ! -f "$evidence/gui/gui-result.json" ]]; then printf 'FAIL: missing saved termination or GUI result\n'; return 1; fi
    local result="$evidence/gui/gui-result.json" actual_pid actual_status completed
    actual_pid=$(/usr/bin/plutil -extract pid raw -o - "$result") || return 1
    actual_status=$(/usr/bin/plutil -extract status raw -o - "$result") || return 1
    completed=$(/usr/bin/plutil -extract completed raw -o - "$result") || return 1
    if [[ "$actual_pid" != "$pid" || "$actual_status" != passed || "$completed" != true ]]; then printf 'FAIL: GUI result is not a completed pass for PID %s\n' "$pid"; return 1; fi
    printf 'PASS GUI process=%s exit=0 saved termination and completed result verified\n' "$pid"
}
# This is the same result gate used after wait below, exposed for negative regression checks.
if [[ "${1:-}" == --check-gui-result ]]; then
    if [[ $# != 4 || "$2" != /* || ! "$3" =~ ^[0-9]+$ || ! "$4" =~ ^[0-9]+$ ]]; then exit 64; fi
    check_gui_result "$2" "$3" "$4"; exit $?
fi
GUI_ONLY=false
if [[ "${1:-}" == --gui-only ]]; then GUI_ONLY=true; shift; fi
if [[ $# != 2 || "$1" != /* || "$2" != /* ]]; then printf 'Usage: bash test.sh [--gui-only] /absolute/new-evidence-dir /absolute/build-dir\n' >&2; exit 64; fi
EVIDENCE="$1"
BUILD="$2"
if [[ -e "$EVIDENCE" ]]; then printf 'Refuse existing evidence dir; use a fresh directory\n' >&2; exit 64; fi
mkdir -p "$EVIDENCE"
exec > >(tee "$EVIDENCE/commands.log") 2>&1
printf 'BUILD: bash %q %q\n' "$ROOT/build.sh" "$BUILD"
bash "$ROOT/build.sh" "$BUILD"
BIN="$BUILD/PaperDock.app/Contents/MacOS/PaperDock"
if [[ "$GUI_ONLY" == false ]]; then
for suite in title dates query controller palette editor windows hsv bad-store; do
    printf 'RUN: %q --test %s --data-dir %q\n' "$BIN" "$suite" "$EVIDENCE/data-$suite"
    "$BIN" --test "$suite" --data-dir "$EVIDENCE/data-$suite" > "$EVIDENCE/$suite.log" 2>&1
    printf '%s EXIT=0\n' "$suite"
done
for suite in write read read-random; do
    printf 'RUN: %q --test %s --data-dir %q\n' "$BIN" "$suite" "$EVIDENCE/data-restart"
    "$BIN" --test "$suite" --data-dir "$EVIDENCE/data-restart" > "$EVIDENCE/$suite.log" 2>&1
    printf '%s EXIT=0\n' "$suite"
done
fi
printf 'RUN: %q --gui-test --data-dir %q --evidence-dir %q\n' "$BIN" "$EVIDENCE/data-gui" "$EVIDENCE/gui"
"$BIN" --gui-test --data-dir "$EVIDENCE/data-gui" --evidence-dir "$EVIDENCE/gui" > "$EVIDENCE/gui.log" 2>&1 &
PID=$!
printf 'GUI PID=%s\n' "$PID"
STATUS=0
wait "$PID" || STATUS=$?
printf 'GUI EXIT=%s\n' "$STATUS"
check_gui_result "$EVIDENCE" "$PID" "$STATUS"
printf 'PASS requested programmatic checks; human interaction and system screenshots are NOT verified\n'
