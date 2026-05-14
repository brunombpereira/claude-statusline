#!/usr/bin/env bash
# tests/run.sh — snapshot tests for statusline.sh.
#
# For each tests/fixtures/*.json, pipe it through statusline.sh with all
# volatile inputs pinned (time, timezone, env detection, VCS), strip ANSI,
# and compare against tests/expected/<name>.txt.
#
#   bash tests/run.sh             # run tests
#   bash tests/run.sh --update    # rewrite expected/ from current output
#   bash tests/run.sh --diff      # show diffs but exit 0 (useful in CI debug)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATUSLINE="$REPO_ROOT/statusline.sh"
FIXTURES="$SCRIPT_DIR/fixtures"
EXPECTED="$SCRIPT_DIR/expected"

UPDATE=0; DIFF_ONLY=0
case "${1:-}" in
  --update) UPDATE=1 ;;
  --diff)   DIFF_ONLY=1 ;;
  '') ;;
  *) echo "unknown arg: $1" >&2; exit 2 ;;
esac

mkdir -p "$EXPECTED"

# Pinned inputs so output is deterministic on any machine.
export STATUSLINE_TEST_NOW=1747200000       # 2025-05-14 09:20 UTC
export TZ=UTC
export NO_COLOR=1
export STATUSLINE_SHOW_ENV=0                # don't probe ruby/node/python
export STATUSLINE_VCS=off                   # don't shell out to git/jj
export COLUMNS=200                          # full mode
unset CLAUDE_STATUSLINE_COMPACT

strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }

pass=0; fail=0
shopt -s nullglob
for fixture in "$FIXTURES"/*.json; do
  name=$(basename "$fixture" .json)
  expected_file="$EXPECTED/$name.txt"

  actual=$(bash "$STATUSLINE" < "$fixture" | strip_ansi)

  if (( UPDATE )); then
    printf '%s\n' "$actual" > "$expected_file"
    echo "[updated] $name"
    continue
  fi

  if [[ ! -f "$expected_file" ]]; then
    echo "[missing] $name — no expected file (run with --update to create)"
    (( fail++ )) || true
    continue
  fi

  expected=$(<"$expected_file")
  if [[ "$actual" == "$expected" ]]; then
    echo "[ok]      $name"
    (( pass++ )) || true
  else
    echo "[fail]    $name"
    diff <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") || true
    (( fail++ )) || true
  fi
done

if (( UPDATE )); then
  exit 0
fi

echo
echo "passed: $pass, failed: $fail"
if (( DIFF_ONLY )); then
  exit 0
fi
exit $(( fail > 0 ? 1 : 0 ))
