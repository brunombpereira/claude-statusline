#!/usr/bin/env bash
# install.sh — install the Claude Code status line.
#
# Copies statusline.sh into ~/.claude/ (or $CLAUDE_CONFIG_DIR) and merges the
# statusLine block into settings.json. The existing settings.json is backed up
# with a timestamped suffix before being rewritten.
#
# Usage:
#   bash install.sh             # install
#   bash install.sh --help      # show this help

set -euo pipefail

usage() {
  cat <<'EOF'
install.sh — install the Claude Code status line

USAGE
    bash install.sh
    bash install.sh --help

WHAT IT DOES
    1. Copies statusline.sh to $CLAUDE_CONFIG_DIR/statusline.sh
       (defaults to ~/.claude/statusline.sh).
    2. Backs up the existing settings.json with a timestamped suffix.
    3. Merges a "statusLine" block into settings.json pointing at the
       installed script.

ENVIRONMENT
    CLAUDE_CONFIG_DIR    Override the install directory (default ~/.claude).

REQUIREMENTS
    bash 4+, python3, git (optional, only used at runtime).

UNINSTALL
    bash uninstall.sh
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

# ── Dependency checks ───────────────────────────────────────────────────────
if ! command -v python3 >/dev/null 2>&1; then
  echo "[error] python3 is required but was not found in PATH." >&2
  exit 1
fi

if (( BASH_VERSINFO[0] < 4 )); then
  echo "[error] bash 4+ is required (you are running ${BASH_VERSION})." >&2
  exit 1
fi

# ── Paths ───────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_SCRIPT="$SCRIPT_DIR/statusline.sh"

if [[ ! -f "$SRC_SCRIPT" ]]; then
  echo "[error] statusline.sh not found next to install.sh ($SRC_SCRIPT)." >&2
  exit 1
fi

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DST_SCRIPT="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"

mkdir -p "$CLAUDE_DIR"

# ── Copy the script ─────────────────────────────────────────────────────────
cp "$SRC_SCRIPT" "$DST_SCRIPT"
chmod +x "$DST_SCRIPT"
echo "[ok] installed statusline.sh -> $DST_SCRIPT"

# ── Back up existing settings ───────────────────────────────────────────────
if [[ -f "$SETTINGS" ]]; then
  BACKUP="$SETTINGS.bak.$(date +%Y%m%d-%H%M%S)"
  cp "$SETTINGS" "$BACKUP"
  echo "[ok] backed up existing settings.json -> $BACKUP"
fi

# ── Merge the statusLine block ──────────────────────────────────────────────
python3 - "$SETTINGS" "$DST_SCRIPT" <<'PY'
import json, os, sys
path, script = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except Exception as e:
        print(f"[warn] existing settings.json could not be parsed ({e}); rewriting from scratch")
        data = {}
data["statusLine"] = {
    "type": "command",
    "command": f"bash {script}",
    "padding": 1,
    "refreshInterval": 1,
}
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print(f"[ok] merged statusLine block into {path}")
PY

echo
echo "Done. Restart Claude Code to see the status line."
