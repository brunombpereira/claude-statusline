# Contributing

Thanks for considering a contribution. The whole project is a single bash
script plus a thin installer, so the contribution loop is short.

## Project layout

```
statusline.sh           # the status line itself (bash + one python3 call)
install.sh              # copies statusline.sh to ~/.claude and merges settings
uninstall.sh            # reverse of install.sh
settings-snippet.json   # what install.sh merges into settings.json
tests/
  fixtures/*.json       # sample Claude Code JSON payloads
  expected/*.txt        # expected rendered output (ANSI stripped)
  run.sh                # snapshot test runner
.github/workflows/      # CI (runs tests on ubuntu + macos)
docs/preview.png        # README screenshot
```

## Running the tests

```bash
bash tests/run.sh           # run snapshot tests
bash tests/run.sh --update  # rewrite expected/ from current output
```

The runner pins every volatile input — time (`STATUSLINE_TEST_NOW`), timezone
(`TZ=UTC`), env detection (`STATUSLINE_SHOW_ENV=0`), VCS lookup
(`STATUSLINE_VCS=off`), color (`NO_COLOR=1`), and terminal width
(`COLUMNS=200`) — so output is deterministic across machines.

If your change deliberately alters the rendered output (e.g. new segment, new
color), run `tests/run.sh --update` and commit the updated snapshots
alongside the code change.

## Configuration variables

The script reads these environment variables (and the same names can be set
in `~/.claude/statusline.conf`, which is shell-sourced if it exists):

| Variable | Effect |
| --- | --- |
| `CLAUDE_STATUSLINE_COMPACT` | `1` forces compact mode regardless of `COLUMNS` |
| `CLAUDE_STATUSLINE_DEBUG` | `1` logs raw JSON + parsed fields to `statusline-debug.log` |
| `CLAUDE_CONFIG_DIR` | Overrides `~/.claude` as the install / cache root |
| `NO_COLOR` | Any non-empty value suppresses all ANSI escapes |
| `STATUSLINE_SHOW_ENV` | `0` hides the env (WSL/python/ruby/node) segment |
| `STATUSLINE_SHOW_VERSION` | `0` hides the Claude Code version |
| `STATUSLINE_SHOW_BURN` | `0` hides the `$/h` burn-rate indicator |
| `STATUSLINE_SHOW_STASH` | `0` hides the git stash counter |
| `STATUSLINE_SHOW_DATE` | `0` hides the weekday/date next to the clock |
| `STATUSLINE_SHOW_OUTPUT_STYLE` | `0` hides the `★output_style` badge |
| `STATUSLINE_VCS` | `auto` (default) / `git` / `jj` / `off` |
| `STATUSLINE_TEST_NOW` | Pins "now" to a unix timestamp — used by the test harness |

Palette colors can also be overridden in `statusline.conf` by reassigning the
ANSI variables (`GRN`, `YEL`, `ORG`, `RED`, `BLU`, `CYN`, `GLD`, `PNK`,
`PUR`, `WHT`, `GRY`). Use `$'\033[38;5;Nm'` form so the escapes survive.

## Style

- Bash 4+. No external deps beyond `python3`, `git`, and (optionally) `jj`.
- One `python3` invocation per refresh — don't add more spawns to the hot path.
- Add a `STATUSLINE_SHOW_<thing>` toggle for any new segment so users can opt out.
- Update `tests/fixtures/` and `tests/expected/` for any rendering change.
- Bump `VERSION` in `statusline.sh` and add a `CHANGELOG.md` entry.

## Filing issues

Use the bug-report or feature-request templates under `.github/ISSUE_TEMPLATE/`.
Screenshots and the relevant slice of `statusline-debug.log` (with
`CLAUDE_STATUSLINE_DEBUG=1`) make almost every bug trivial to reproduce.
