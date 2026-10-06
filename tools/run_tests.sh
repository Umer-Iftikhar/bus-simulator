#!/usr/bin/env bash
# Runs a test suite headless.
#   tools/run_tests.sh [unit|integration|system|all] [--filter=name]
# Set GODOT to the Godot 4.4 executable (defaults to `godot` on PATH).
set -uo pipefail

GODOT="${GODOT:-godot}"
SUITE="${1:-all}"
shift || true
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORTS="$ROOT/reports"
mkdir -p "$REPORTS"
touch "$REPORTS/.gdignore"

ERROR_PATTERN="SCRIPT ERROR|Parse Error|Failed to load script|Compile Error"

echo "::group::Import project"
"$GODOT" --headless --path "$ROOT" --import >"$REPORTS/import.log" 2>&1
echo "import exit code: $?"
echo "::endgroup::"
if grep -qE "$ERROR_PATTERN" "$REPORTS/import.log"; then
  grep -E -A3 "$ERROR_PATTERN" "$REPORTS/import.log"
  echo "::error::Script errors while importing the project"
  exit 1
fi

LOG="$REPORTS/$SUITE.log"
"$GODOT" --headless --path "$ROOT" --fixed-fps 60 \
  -s res://tests/framework/runner.gd -- \
  --suite="$SUITE" --junit="res://reports/$SUITE.xml" "$@" 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}

if grep -qE "$ERROR_PATTERN" "$LOG"; then
  echo "::error::Script errors were raised while running the $SUITE suite"
  status=1
fi
exit "$status"
