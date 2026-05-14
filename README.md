# Claude Code Status Line

A two-line, information-dense status line for [Claude Code](https://docs.claude.com/en/docs/claude-code) — workspace, git, model, time, environment, context, cost, and rate-limit windows, all at a glance.

![shell](https://img.shields.io/badge/shell-bash-1f425f.svg)
![license](https://img.shields.io/badge/license-MIT-blue.svg)
![claude code](https://img.shields.io/badge/claude--code-status%20line-7a5af8.svg)

---

## Preview

```
▎ claude-statusline › src  │  main ●3 +1 ~2 ?1 +47/-12  │  Opus 4.7 1M ★concise v2.0.42  │  14:32 Thu 14  │  WSL · ruby 3.3 · node 22
▎ ctx ██▎░░░░░░░ 23% 187k/1.00M  │  $0.487 2m22s +569/-0  │  5h ████▎░░░ 52% →18:00 (3h28m)  │  7d ███▎░░░░ 41% →Mon 18 (3d20h)
```

**Line 1** — workspace · git · model · time · environment
**Line 2** — context bar · session cost · 5-hour rate limit · 7-day rate limit

| Segment | Shows |
| --- | --- |
| `repo › subpath` | Project name and sub-path within the project |
| `main ●3 +1 ~2 ?1 +47/-12` | Branch, dirty count, staged/unstaged/untracked, diff `+/-` lines, ahead/behind |
| `Opus 4.7 1M ★concise v2.0.42` | Model, 1M-context tag, output style, Claude Code version |
| `14:32 Thu 14` | Local time and weekday |
| `WSL · ruby 3.3 · node 22` | Environment (cached 1h) |
| `ctx … 23% 187k/1.00M` | Context window used, with sub-cell precision bar |
| `$0.487 2m22s +569/-0` | Total session cost, duration, lines added/removed |
| `5h … 52% →18:00 (3h28m)` | 5-hour rate-limit window: used %, absolute reset, ETA |
| `7d … 41% →Mon 18 (3d20h)` | 7-day rate-limit window: used %, absolute reset, ETA |

Colors shift `green → yellow → orange → red` as bars approach 100%. The status line auto-compacts when the terminal is narrower than 100 columns.

---

## Install

The installer copies `statusline.sh` to `~/.claude/` and merges the `statusLine` block into `~/.claude/settings.json` (a timestamped backup is created first).

### From a clone

```bash
git clone https://github.com/brunombpereira/claude-statusline.git
cd claude-statusline
bash install.sh
```

### With GitHub CLI

```bash
gh repo clone brunombpereira/claude-statusline
cd claude-statusline
bash install.sh
```

Restart Claude Code (or open a new session) to see the status line.

---

## Requirements

- **bash** 4 or newer
- **python3** (one short script parses Claude Code's JSON input)
- **git** (optional — only used to populate the git segment)

Designed for Linux, macOS, and WSL. The environment segment auto-detects WSL, Node, and Ruby; it's cached for one hour to keep the status line snappy.

---

## Configuration

### Environment variables

| Variable | Effect |
| --- | --- |
| `CLAUDE_STATUSLINE_COMPACT=1` | Force compact mode regardless of terminal width |
| `CLAUDE_STATUSLINE_DEBUG=1` | Log the raw Claude Code JSON to `~/.claude/statusline-debug.log` |
| `CLAUDE_CONFIG_DIR` | Override the install location (default `~/.claude`) |
| `COLUMNS` | If set and below `100`, compact mode kicks in automatically |

Set them in your shell rc or via Claude Code's environment configuration.

### Refresh interval

The installer writes a `refreshInterval: 1` second. To slow it down, edit `~/.claude/settings.json` and bump the number — useful on slow machines or remote shells.

### Custom colors

The palette lives near the top of `statusline.sh`, around the `# ─── ANSI palette` block. The codes are standard 256-color escapes (`\033[38;5;N`), so you can change them without touching any logic.

---

## How it works

Claude Code invokes the `statusLine.command` once per refresh interval and pipes a JSON payload describing the current session (workspace, model, context usage, cost, rate limits) on stdin. The script:

1. Parses the JSON in a single `python3` call.
2. Runs one `git status --porcelain=v2 --branch` for the workspace.
3. Renders two lines with ANSI 256-color escapes, picking colors based on percentage thresholds.
4. Caches the environment segment (WSL/Node/Ruby) to disk for one hour.

The whole thing finishes in well under 100 ms on a modern machine.

---

## Manual install

1. Copy `statusline.sh` to `~/.claude/statusline.sh` and make it executable:
   ```bash
   mkdir -p ~/.claude
   cp statusline.sh ~/.claude/statusline.sh
   chmod +x ~/.claude/statusline.sh
   ```
2. Merge the block from `settings-snippet.json` into `~/.claude/settings.json`, replacing `YOUR_USER` with your actual username:
   ```json
   "statusLine": {
     "type": "command",
     "command": "bash /home/YOUR_USER/.claude/statusline.sh",
     "padding": 1,
     "refreshInterval": 1
   }
   ```
3. Restart Claude Code.

---

## Uninstall

```bash
bash uninstall.sh
```

This removes `~/.claude/statusline.sh` and strips the `statusLine` block from `~/.claude/settings.json`. Backups produced by `install.sh` are left in place so you can roll back manually if needed.

---

## Troubleshooting

**The status line doesn't appear after installing.** Restart Claude Code so it re-reads `settings.json`. Check `~/.claude/settings.json` for a `statusLine` block pointing at `bash <abs-path>/statusline.sh`.

**No git info shows.** The script silently skips git when the workspace isn't a git repo. If you expect git info, run `git -C <cwd> status` manually to confirm git can read the directory.

**Layout looks cramped or wrapped.** Either your terminal is narrower than 100 columns (compact mode auto-engages) or your terminal's reported `COLUMNS` is wrong. Force full mode by unsetting `CLAUDE_STATUSLINE_COMPACT`; force compact mode by setting `CLAUDE_STATUSLINE_COMPACT=1`.

**Something is parsing wrong.** Set `CLAUDE_STATUSLINE_DEBUG=1` and tail `~/.claude/statusline-debug.log` — you'll see the raw JSON Claude Code is sending and the parsed fields.

**Environment segment is stale.** Delete `~/.claude/.statusline-env-cache` to force a refresh.

---

## Contributing

Issues and pull requests are welcome. If you have a tweak — different palette, extra segment, alternative compact layout — open a PR. Keep changes focused and try not to balloon the script with rarely-used features.

---

## License

[MIT](LICENSE) © Bruno Pereira
