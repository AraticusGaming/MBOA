#!/usr/bin/env bash
# Runs every headless test in tests/. Usage: tests/run_all.sh [path/to/godot]
# Fails if any suite exits non-zero or prints a SCRIPT ERROR / engine ERROR.
set -u
GODOT="${1:-${GODOT:-godot}}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
status=0
for t in "$ROOT"/tests/test_*.gd; do
  name="$(basename "$t")"
  [ "$name" = "test_base.gd" ] && continue
  out="$("$GODOT" --headless --path "$ROOT" --script "res://tests/$name" 2>&1)"
  code=$?
  echo "$out" | grep -Ev '^(Godot Engine|$)'
  if [ $code -ne 0 ] || echo "$out" | grep -qE 'SCRIPT ERROR|^ERROR:|Parse Error'; then
    echo "!! $name FAILED (exit $code)"
    status=1
  fi
done
[ $status -eq 0 ] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit $status
