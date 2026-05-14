#!/usr/bin/env bash
# uninstall.sh — remove the Claude Code status line.
#
# Deletes ~/.claude/statusline.sh (or $CLAUDE_CONFIG_DIR/statusline.sh) and
# removes the statusLine block from settings.json. A timestamped backup of
# settings.json is created first. Backups produced by install.sh are left in
# place.
#
# Usage:
#   bash uninstall.sh
#   bash uninstall.sh --help

set -euo pipefail

usage() {
  cat <<'EOF'
uninstall.sh — remove the Claude Code status line

USAGE
    bash uninstall.sh
    bash uninstall.sh --help

WHAT IT DOES
    1. Backs up settings.json with a timestamped suffix.
    2. Removes the "statusLine" key from settings.json.
    3. Deletes the installed statusline.sh and its runtime cache files.

ENVIRONMENT
    CLAUDE_CONFIG_DIR    Override the install directory (default ~/.claude).
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "[error] python3 is required but was not found in PATH." >&2
  exit 1
fi

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DST_SCRIPT="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"
ENV_CACHE="$CLAUDE_DIR/.statusline-env-cache"
DEBUG_LOG="$CLAUDE_DIR/statusline-debug.log"

# ── Strip statusLine from settings.json ─────────────────────────────────────
if [[ -f "$SETTINGS" ]]; then
  BACKUP="$SETTINGS.bak.$(date +%Y%m%d-%H%M%S)"
  cp "$SETTINGS" "$BACKUP"
  echo "[ok] backed up settings.json -> $BACKUP"

  python3 - "$SETTINGS" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except Exception as e:
    print(f"[warn] settings.json could not be parsed ({e}); leaving it alone")
    sys.exit(0)
if isinstance(data, dict) and data.pop("statusLine", None) is not None:
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print(f"[ok] removed statusLine block from {path}")
else:
    print(f"[ok] no statusLine block to remove from {path}")
PY
else
  echo "[ok] no settings.json found at $SETTINGS — skipping"
fi

# ── Remove installed script + runtime artifacts ─────────────────────────────
for path in "$DST_SCRIPT" "$ENV_CACHE" "$DEBUG_LOG"; do
  if [[ -e "$path" ]]; then
    rm -f "$path"
    echo "[ok] removed $path"
  fi
done

echo
echo "Done. Restart Claude Code to drop the status line."
