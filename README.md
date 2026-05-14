# Claude Code — Status Line (replicar)

Status line de duas linhas para o Claude Code:

- **L1**: repo › subpasta │ git (branch · dirty · staged/unstaged/untracked · diff +/- · ahead/behind · estado de rebase/merge) │ modelo · output_style · versão │ hora · data │ env (WSL · ruby · node, cache 1h)
- **L2**: barra ctx % tokens │ custo · duração · linhas │ barra 5h % reset │ barra 7d % reset

Auto-compacta se `COLUMNS < 100`. Forçar compacto: `CLAUDE_STATUSLINE_COMPACT=1`. Debug: `CLAUDE_STATUSLINE_DEBUG=1` → `~/.claude/statusline-debug.log`.

## Conteúdo da pasta

- `statusline.sh` — o script propriamente dito
- `settings-snippet.json` — bloco a fundir em `~/.claude/settings.json`
- `install.sh` — instalador automático (copia o script e funde o snippet, faz backup do settings)

## Instalação (recomendada)

Numa shell bash (WSL/Linux/macOS):

```bash
bash install.sh
```

Depois reinicia o Claude Code.

## Instalação manual

1. Copia `statusline.sh` para `~/.claude/statusline.sh` e dá-lhe permissões de execução:
   ```bash
   mkdir -p ~/.claude
   cp statusline.sh ~/.claude/statusline.sh
   chmod +x ~/.claude/statusline.sh
   ```
2. Edita `~/.claude/settings.json` e adiciona/funde o bloco em `settings-snippet.json`:
   ```json
   "statusLine": {
     "type": "command",
     "command": "bash /home/<user>/.claude/statusline.sh",
     "padding": 1,
     "refreshInterval": 1
   }
   ```
   Ajusta o caminho de `command` se o teu `~` não for `/home/wiremaze`.
3. Reinicia o Claude Code.

## Requisitos

- bash 4+
- python3 (parsing do JSON de input do Claude Code)
- git (opcional, para o segmento de git)
