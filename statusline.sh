#!/usr/bin/env bash
# ============================================================================
#  ~/.claude/statusline.sh — Premium status line for Claude Code
# ----------------------------------------------------------------------------
#  Two-line dashboard with:
#    L1 → repo › subpath │ git (branch · dirty · staged/unstaged/untracked
#                         · diff +/- · ahead/behind · rebase/merge state)
#         │ model · output_style · version │ time · date │ env (cached)
#    L2 → ctx bar % tokens │ cost · duration · lines │ 5h bar % reset
#                                                    │ 7d bar % reset
#
#  Auto compact mode when COLUMNS < 110.
#
#  Debug:  CLAUDE_STATUSLINE_DEBUG=1   →  ~/.claude/statusline-debug.log
#  Deps :  bash 4+, python3, git (optional)
# ============================================================================

set -u
input=$(cat)

LOG=~/.claude/statusline-debug.log
ENV_CACHE=~/.claude/.statusline-env-cache

# ─── Debug logging ──────────────────────────────────────────────────────────
if [[ "${CLAUDE_STATUSLINE_DEBUG:-0}" == "1" ]]; then
  {
    printf '\n=== %s ===\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'RAW: %s\n' "$input"
    python3 -c '
import sys, json
def walk(o, p=""):
    if isinstance(o, dict):
        for k, v in o.items(): walk(v, f"{p}{k}.")
    elif isinstance(o, list):
        for i, v in enumerate(o): walk(v, f"{p}[{i}].")
    else:
        print(f"  {p[:-1] or chr(60)+chr(62)} = {repr(o)[:140]}")
try: walk(json.loads(sys.stdin.read()))
except Exception as e: print("  parse_error:", e)
' <<< "$input"
  } >> "$LOG" 2>&1
fi

# ─── JSON parsing (single python3 call, 24 lines out) ───────────────────────
PY_CODE=$(cat << 'PYEOF'
import sys, json, time
from datetime import datetime

raw = sys.stdin.read()
try:
    d = json.loads(raw)
except Exception:
    d = {}

def g(path, default=''):
    v = d
    for k in path.split('.'):
        if isinstance(v, dict):
            v = v.get(k)
        else:
            return default
        if v is None:
            return default
    return '' if v == {} else str(v)

def fmt_tokens(n):
    try: v = float(n)
    except Exception: return '0'
    if v >= 1_000_000: return f'{v/1_000_000:.2f}M'
    if v >= 1_000:     return f'{v/1_000:.0f}k'
    return str(int(v))

def fmt_dur(ms):
    try: s = float(ms) / 1000
    except Exception: return ''
    if s < 1:    return ''
    if s < 60:   return f'{int(s)}s'
    if s < 3600: return f'{int(s//60)}m{int(s%60):02d}s'
    h = int(s//3600); m = int((s%3600)//60)
    return f'{h}h{m:02d}m'

def fmt_reset_abs(ts):
    if not ts: return ''
    try:
        diff = float(ts) - time.time()
        if diff <= 0: return 'now'
        t = datetime.fromtimestamp(float(ts))
        if diff < 86400: return t.strftime('%H:%M')
        days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']
        return days[t.weekday()] + ' ' + t.strftime('%d')
    except Exception: return ''

def fmt_reset_eta(ts):
    if not ts: return ''
    try:
        diff = float(ts) - time.time()
        if diff <= 0: return 'now'
        if diff < 3600:  return f'{int(diff//60)}m'
        if diff < 86400: return f'{int(diff//3600)}h{int((diff%3600)//60):02d}m'
        return f'{int(diff//86400)}d{int((diff%86400)//3600)}h'
    except Exception: return ''

def to_pct(v, default=-1):
    try: return max(0, min(100, round(float(v))))
    except Exception: return default

cwd        = g('workspace.current_dir') or g('cwd')
proj_dir   = g('workspace.project_dir')
model_id   = g('model.id')
model_name = g('model.display_name')
version    = g('version')
out_style  = g('output_style.name')
sess_id    = g('session_id')

ctx_pct  = g('context_window.used_percentage', '0')
ctx_used = g('context_window.total_input_tokens', '0')
ctx_size = g('context_window.context_window_size', '0')

cost_usd  = g('cost.total_cost_usd', '0')
cost_dur  = g('cost.total_duration_ms', '0')
cost_api  = g('cost.total_api_duration_ms', '0')
lines_add = g('cost.total_lines_added', '0')
lines_del = g('cost.total_lines_removed', '0')

r5_pct   = g('rate_limits.five_hour.used_percentage')
r5_reset = g('rate_limits.five_hour.resets_at')
r7_pct   = g('rate_limits.seven_day.used_percentage')
r7_reset = g('rate_limits.seven_day.resets_at')

try: cost_fmt = f'{float(cost_usd):.3f}'
except Exception: cost_fmt = '0.000'

try: la = int(float(lines_add or 0))
except Exception: la = 0
try: ld = int(float(lines_del or 0))
except Exception: ld = 0

now = datetime.now()
out = [
    cwd, proj_dir, model_id, model_name, version, out_style,
    sess_id[-6:] if sess_id else '',
    str(to_pct(ctx_pct, 0)),
    fmt_tokens(ctx_used),
    fmt_tokens(ctx_size),
    cost_fmt,
    fmt_dur(cost_dur),
    fmt_dur(cost_api),
    str(la),
    str(ld),
    str(to_pct(r5_pct, -1)),
    fmt_reset_abs(r5_reset),
    fmt_reset_eta(r5_reset),
    str(to_pct(r7_pct, -1)),
    fmt_reset_abs(r7_reset),
    fmt_reset_eta(r7_reset),
    now.strftime('%H:%M'),
    now.strftime('%a %d'),
    # 1M tag — only if id signals it AND display_name doesn't already say so
    ('1M' if model_id and '1m' in model_id.lower()
            and '1m' not in (model_name or '').lower()
       else ''),
]
for line in out:
    print(line if line is not None else '')
PYEOF
)

mapfile -t F < <(printf '%s' "$input" | python3 -c "$PY_CODE" 2>/dev/null)

cwd="${F[0]:-}"
proj_dir="${F[1]:-}"
model_id="${F[2]:-}"
model_name="${F[3]:-}"
version="${F[4]:-}"
out_style="${F[5]:-}"
sess_short="${F[6]:-}"
ctx_pct="${F[7]:-0}"
ctx_used="${F[8]:-0}"
ctx_size="${F[9]:-0}"
cost_fmt="\$${F[10]:-0.000}"
cost_dur="${F[11]:-}"
cost_api="${F[12]:-}"
lines_add="${F[13]:-0}"
lines_del="${F[14]:-0}"
r5_pct="${F[15]:--1}"
r5_abs="${F[16]:-}"
r5_eta="${F[17]:-}"
r7_pct="${F[18]:--1}"
r7_abs="${F[19]:-}"
r7_eta="${F[20]:-}"
clock="${F[21]:-}"
today="${F[22]:-}"
ctx_tag="${F[23]:-}"

# ─── Terminal width ─────────────────────────────────────────────────────────
# Claude Code does not reliably set COLUMNS when invoking the status-line
# command, so we default to FULL mode unless the env var is explicitly small.
# Override with CLAUDE_STATUSLINE_COMPACT=1 to force compact, or set COLUMNS.
COLS=${COLUMNS:-0}
COMPACT=0
if [[ "${CLAUDE_STATUSLINE_COMPACT:-0}" == "1" ]]; then
  COMPACT=1
elif (( COLS > 0 && COLS < 100 )); then
  COMPACT=1
fi

# ─── Project name + sub-path ────────────────────────────────────────────────
repo_name=""; sub_path=""
if [[ -n "$cwd" ]]; then
  if [[ -n "$proj_dir" && "$cwd" == "$proj_dir"* ]]; then
    repo_name=$(basename "$proj_dir")
    rel="${cwd#$proj_dir}"
    sub_path="${rel#/}"
  else
    repo_name=$(basename "$cwd")
  fi
fi
if (( COMPACT )) && [[ -n "$sub_path" && ${#sub_path} -gt 18 ]]; then
  sub_path="…/$(basename "$(dirname "$sub_path")")/$(basename "$sub_path")"
fi

# ─── Git info (single porcelain v2 call) ────────────────────────────────────
branch=""; dirty=0; staged=0; unstaged=0; untracked=0
ahead=0; behind=0; git_state=""; diff_a=0; diff_d=0

if [[ -n "$cwd" ]] && git_top=$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null); then
  if [[ -d "$git_top/.git/rebase-merge" || -d "$git_top/.git/rebase-apply" ]]; then
    git_state="rebase"
  elif [[ -f "$git_top/.git/MERGE_HEAD" ]]; then
    git_state="merge"
  elif [[ -f "$git_top/.git/CHERRY_PICK_HEAD" ]]; then
    git_state="cherry"
  elif [[ -f "$git_top/.git/REVERT_HEAD" ]]; then
    git_state="revert"
  fi

  porcelain=$(git -C "$cwd" --no-optional-locks status --porcelain=v2 --branch 2>/dev/null) || porcelain=""

  while IFS= read -r line; do
    case "$line" in
      "# branch.head "*)
        branch="${line#\# branch.head }"
        [[ "$branch" == "(detached)" ]] && branch=""
        ;;
      "# branch.ab "*)
        ab="${line#\# branch.ab }"
        a_part="${ab%% *}"; b_part="${ab##* }"
        ahead="${a_part#+}"; behind="${b_part#-}"
        ;;
      "1 "*|"2 "*)
        ((dirty++)) || true
        xy="${line:2:2}"
        x="${xy:0:1}"; y="${xy:1:1}"
        [[ "$x" != "." && "$x" != " " ]] && { ((staged++))   || true; }
        [[ "$y" != "." && "$y" != " " ]] && { ((unstaged++)) || true; }
        ;;
      "u "*)
        ((dirty++))    || true
        ((unstaged++)) || true
        ;;
      "? "*)
        ((dirty++))     || true
        ((untracked++)) || true
        ;;
    esac
  done <<< "$porcelain"

  if [[ -z "$branch" ]]; then
    sha=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
    [[ -n "$sha" ]] && branch="@${sha}"
  fi

  if (( dirty > 0 )); then
    read -r diff_a diff_d < <(
      git -C "$cwd" --no-optional-locks diff HEAD --numstat 2>/dev/null \
      | awk '$1!="-" && $2!="-" {a+=$1; d+=$2} END{printf "%d %d", a+0, d+0}'
    )
    diff_a=${diff_a:-0}; diff_d=${diff_d:-0}
  fi
fi

# ─── Environment info (cached 1h) ───────────────────────────────────────────
env_info=""
if [[ -f "$ENV_CACHE" ]] && (( $(date +%s) - $(stat -c %Y "$ENV_CACHE" 2>/dev/null || echo 0) < 3600 )); then
  env_info=$(<"$ENV_CACHE")
else
  parts=()
  grep -qi microsoft /proc/version 2>/dev/null && parts+=("WSL")
  if command -v ruby &>/dev/null; then
    rb=$(ruby -e 'print RUBY_VERSION' 2>/dev/null)
    [[ -n "$rb" ]] && parts+=("ruby ${rb%.*}")
  fi
  if command -v node &>/dev/null; then
    nv=$(node -v 2>/dev/null | tr -d 'v')
    [[ -n "$nv" ]] && parts+=("node ${nv%%.*}")
  fi
  joined=""
  for p in "${parts[@]:-}"; do
    [[ -z "$p" ]] && continue
    [[ -n "$joined" ]] && joined+=" · "
    joined+="$p"
  done
  env_info="$joined"
  printf '%s' "$env_info" > "$ENV_CACHE" 2>/dev/null || true
fi

# ─── ANSI palette (256-color) ───────────────────────────────────────────────
R=$'\033[0m'
B=$'\033[1m'
DIM=$'\033[2m'
GRN=$'\033[38;5;76m'
YEL=$'\033[38;5;220m'
ORG=$'\033[38;5;208m'
RED=$'\033[38;5;203m'
BLU=$'\033[38;5;39m'
CYN=$'\033[38;5;87m'
GLD=$'\033[38;5;214m'
PNK=$'\033[38;5;213m'
PUR=$'\033[38;5;177m'
WHT=$'\033[38;5;253m'
GRY=$'\033[38;5;244m'

# ─── Helpers ────────────────────────────────────────────────────────────────
pct_color() {
  local p="${1:-0}"
  (( p < 0 ))   && { printf '%s' "$GRY"; return; }
  (( p >= 90 )) && { printf '%s' "$RED"; return; }
  (( p >= 70 )) && { printf '%s' "$ORG"; return; }
  (( p >= 50 )) && { printf '%s' "$YEL"; return; }
  printf '%s' "$GRN"
}

# Sub-cell precision bar (8 fractional steps per cell)
bar() {
  local pct="${1:-0}" color="$2" size="${3:-10}"
  (( pct < 0 ))   && pct=0
  (( pct > 100 )) && pct=100
  local eighths=$(( pct * size * 8 / 100 ))
  local full=$(( eighths / 8 ))
  local rem=$(( eighths % 8 ))
  local empty=$(( size - full - (rem > 0 ? 1 : 0) ))
  local subs=(' ' '▏' '▎' '▍' '▌' '▋' '▊' '▉')
  printf '%s%s' "$color" "$B"
  local i
  for (( i=0; i<full;  i++ )); do printf '█'; done
  (( rem > 0 )) && printf '%s' "${subs[$rem]}"
  printf '%s' "$DIM"
  for (( i=0; i<empty; i++ )); do printf '░'; done
  printf '%s' "$R"
}

ctx_color=$(pct_color "$ctx_pct")
r5_color=$(pct_color  "$r5_pct")
r7_color=$(pct_color  "$r7_pct")
branch_color=$([[ "$dirty" -gt 0 ]] && printf '%s' "$PNK" || printf '%s' "$GRN")

EDGE="${BLU}${B}▎${R}"
SEP="  ${GRY}│${R}  "

# Join non-empty segments with SEP and prefix with EDGE.
render_line() {
  local first=1 seg
  printf '%s ' "$EDGE"
  for seg in "$@"; do
    [[ -z "$seg" ]] && continue
    (( first )) || printf '%s' "$SEP"
    printf '%s' "$seg"
    first=0
  done
  printf '\n'
}

# ─── Line 1 — workspace · git · model · time · env ──────────────────────────
seg_workspace=""
if [[ -n "$repo_name" ]]; then
  seg_workspace="${B}${CYN}${repo_name}${R}"
  [[ -n "$sub_path" ]] && seg_workspace+=" ${GRY}›${R} ${WHT}${sub_path}${R}"
fi

seg_git=""
if [[ -n "$branch" ]]; then
  seg_git="${branch_color}${B}${branch}${R}"
  [[ -n "$git_state" ]] && seg_git+=" ${RED}${B}[${git_state}]${R}"
  if (( dirty > 0 )); then
    seg_git+=" ${RED}${B}●${R}${RED}${dirty}${R}"
    if (( ! COMPACT )); then
      (( staged    > 0 )) && seg_git+=" ${GRN}+${staged}${R}"
      (( unstaged  > 0 )) && seg_git+=" ${YEL}~${unstaged}${R}"
      (( untracked > 0 )) && seg_git+=" ${BLU}?${untracked}${R}"
      if (( diff_a > 0 || diff_d > 0 )); then
        seg_git+=" ${GRN}+${diff_a}${R}${DIM}/${R}${RED}-${diff_d}${R}"
      fi
    fi
  fi
  (( ahead  > 0 )) && seg_git+=" ${CYN}↑${ahead}${R}"
  (( behind > 0 )) && seg_git+=" ${ORG}↓${behind}${R}"
fi

seg_model=""
if [[ -n "$model_name" ]]; then
  seg_model="${PUR}${B}${model_name}${R}"
  [[ -n "$ctx_tag" ]] && seg_model+=" ${DIM}${ctx_tag}${R}"
  if (( ! COMPACT )); then
    [[ -n "$out_style" && "$out_style" != "default" ]] \
      && seg_model+=" ${GLD}★${R}${DIM}${out_style}${R}"
    [[ -n "$version" ]] && seg_model+=" ${GRY}v${version}${R}"
  fi
fi

seg_time=""
if [[ -n "$clock" ]]; then
  seg_time="${CYN}${B}${clock}${R}"
  (( ! COMPACT )) && [[ -n "$today" ]] && seg_time+=" ${GRY}${today}${R}"
fi

seg_env=""
if (( ! COMPACT )) && [[ -n "$env_info" ]]; then
  seg_env="${DIM}${env_info}${R}"
fi

render_line "$seg_workspace" "$seg_git" "$seg_model" "$seg_time" "$seg_env"

# ─── Line 2 — context · cost · 5h · 7d ──────────────────────────────────────
seg_ctx="${DIM}ctx${R} $(bar "$ctx_pct" "$ctx_color" $((COMPACT ? 6 : 10))) ${ctx_color}${B}${ctx_pct}%${R}"
(( ! COMPACT )) && seg_ctx+=" ${DIM}${ctx_used}/${ctx_size}${R}"

seg_cost="${GLD}${B}${cost_fmt}${R}"
if (( ! COMPACT )); then
  [[ -n "$cost_dur" ]] && seg_cost+=" ${DIM}${cost_dur}${R}"
  if [[ "$lines_add" =~ ^[0-9]+$ && "$lines_del" =~ ^[0-9]+$ ]] \
     && (( lines_add > 0 || lines_del > 0 )); then
    seg_cost+=" ${GRN}+${lines_add}${R}${DIM}/${R}${RED}-${lines_del}${R}"
  fi
fi

seg_r5=""
if (( r5_pct >= 0 )); then
  seg_r5="${DIM}5h${R} $(bar "$r5_pct" "$r5_color" $((COMPACT ? 5 : 8))) ${r5_color}${B}${r5_pct}%${R}"
  if (( ! COMPACT )); then
    [[ -n "$r5_abs" ]] && seg_r5+=" ${GRY}→${r5_abs}${R}"
    [[ -n "$r5_eta" && "$r5_eta" != "$r5_abs" && "$r5_eta" != "now" ]] \
      && seg_r5+=" ${DIM}(${r5_eta})${R}"
  fi
fi

seg_r7=""
if (( r7_pct >= 0 )); then
  seg_r7="${DIM}7d${R} $(bar "$r7_pct" "$r7_color" $((COMPACT ? 5 : 8))) ${r7_color}${B}${r7_pct}%${R}"
  if (( ! COMPACT )); then
    [[ -n "$r7_abs" ]] && seg_r7+=" ${GRY}→${r7_abs}${R}"
    [[ -n "$r7_eta" && "$r7_eta" != "$r7_abs" && "$r7_eta" != "now" ]] \
      && seg_r7+=" ${DIM}(${r7_eta})${R}"
  fi
fi

render_line "$seg_ctx" "$seg_cost" "$seg_r5" "$seg_r7"
