#!/usr/bin/env bash
# Instala a status line do Claude Code copiando o script para ~/.claude/
# e fundindo o bloco statusLine no ~/.claude/settings.json (cria backup).
#
# Uso (a partir desta pasta, dentro de WSL/Linux/macOS):
#   bash install.sh
#
# Pré-requisitos: bash 4+, python3, git (opcional). Para a tag "1M" de
# contexto extra grande aparecer, basta usar Opus 4.x 1M no Claude Code.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_SCRIPT="$SCRIPT_DIR/statusline.sh"

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DST_SCRIPT="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"

mkdir -p "$CLAUDE_DIR"

cp "$SRC_SCRIPT" "$DST_SCRIPT"
chmod +x "$DST_SCRIPT"
echo "[ok] statusline.sh -> $DST_SCRIPT"

if [[ -f "$SETTINGS" ]]; then
  cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d-%H%M%S)"
  echo "[ok] backup criado: $SETTINGS.bak.*"
fi

python3 - "$SETTINGS" "$DST_SCRIPT" <<'PY'
import json, os, sys
path, script = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except Exception as e:
        print(f"[warn] settings.json existente nao pode ser parseado ({e}); a criar de raiz")
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
print(f"[ok] statusLine escrito em {path}")
PY

echo
echo "Feito. Reinicia o Claude Code para veres a status line."
