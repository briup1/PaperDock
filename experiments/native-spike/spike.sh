#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd -P)"
usage() {
  printf 'Usage: %s build | check <NEW-ABS-DATA-DIR> | run <ABS-DATA-DIR> | auto <NEW-ABS-DATA-DIR>\n' "$0" >&2
  exit 2
}
[[ $# -ge 1 ]] || usage
case "$1" in
  build)
    [[ $# -eq 1 ]] || usage
    mkdir -p "$ROOT/build"
    swiftc -warnings-as-errors "$ROOT/Model.swift" "$ROOT/main.swift" -framework AppKit -framework CoreData -o "$ROOT/build/paperdock-spike"
    printf 'Built: %s\n' "$ROOT/build/paperdock-spike"
    ;;
  check|run|auto)
    [[ $# -eq 2 && "$2" == /* ]] || usage
    [[ -x "$ROOT/build/paperdock-spike" ]] || { printf 'Run build first\n' >&2; exit 2; }
    if [[ "$1" != run && -e "$2" ]]; then
      printf 'Refusing existing check/auto directory: %s\n' "$2" >&2; exit 2
    fi
    if [[ "$1" == check ]]; then
      exec "$ROOT/build/paperdock-spike" --data-dir "$2" --check
    elif [[ "$1" == run ]]; then
      exec "$ROOT/build/paperdock-spike" --data-dir "$2"
    else
      # Three foreground app processes, each terminates itself; no global event injection.
      "$ROOT/build/paperdock-spike" --data-dir "$2" --auto seed
      "$ROOT/build/paperdock-spike" --data-dir "$2" --auto read-fixed
      "$ROOT/build/paperdock-spike" --data-dir "$2" --auto read-random
      printf 'PASS three independent AppKit processes; evidence: %s\n' "$2"
    fi
    ;;
  *) usage ;;
esac
