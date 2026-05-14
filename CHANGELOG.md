# Changelog

All notable changes to this project are documented here. Format roughly
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions
follow [SemVer](https://semver.org/).

## [1.1.0] — 2026-05-14

### Added
- `--version` / `--help` flags on `statusline.sh`.
- Optional user config file at `~/.claude/statusline.conf` (shell-sourced).
  Lets you toggle segments and override palette colors without editing the
  script.
- `NO_COLOR` env var support (per https://no-color.org).
- `STATUSLINE_VCS=auto|git|jj|off` — opt-in support for [jujutsu](https://github.com/jj-vcs/jj) repos
  (shows change id + bookmark(s) + dirty flag); auto-detects when both git
  and jj are present.
- Git stash count badge (`⚑N`) in the git segment when stashes exist.
- Burn-rate indicator (`$X.XX/h`) on line 2 once the session has run ≥30s.
- Python venv / interpreter version in the env segment (shows
  `venv <name>` when `$VIRTUAL_ENV` is set, else `py X.Y`).
- Per-segment toggles via env vars: `STATUSLINE_SHOW_ENV`,
  `STATUSLINE_SHOW_VERSION`, `STATUSLINE_SHOW_BURN`,
  `STATUSLINE_SHOW_STASH`, `STATUSLINE_SHOW_DATE`,
  `STATUSLINE_SHOW_OUTPUT_STYLE`.
- Snapshot test harness (`tests/run.sh`) with fixture JSONs and a GitHub
  Actions workflow that runs on Ubuntu and macOS.
- `CONTRIBUTING.md` documenting test workflow, config vars, and style.

### Fixed
- **bash 3.2 compatibility.** Replaced `mapfile` (a bash 4+ builtin) with a
  portable `while read` loop in `statusline.sh` and `install.sh`, and dropped
  the bash-4 version gate. The status line now runs on the stock macOS system
  bash with no Homebrew bash required.
- **macOS env cache.** `stat -c %Y` is GNU-only; on macOS the call failed
  silently and the cache was treated as stale every refresh, re-running
  `ruby`/`node`/`python3` on every status line. Switched to a portable
  `find -mmin +60` check.
- Git state detection now resolves the real gitdir via
  `git rev-parse --git-dir`, so linked worktrees and submodules report
  rebase/merge/cherry/revert state correctly.
- `${cwd#$proj_dir}` is now quoted, preventing glob characters in a project
  path from breaking sub-path extraction.
- Removed an unused `sess_short` variable that was parsed but never rendered.
- Header comment said `COLUMNS < 110` while the code (and README) used 100;
  the comment is corrected.

### Changed
- `install.sh` now prunes old `settings.json.bak.*` files, keeping the 5
  most recent.
- Internal time access goes through helpers so the test harness can pin
  "now" via `STATUSLINE_TEST_NOW`.

## [1.0.0] — 2026-05-14

Initial public release.
