#!/usr/bin/env bash
#
# scaffold.sh - scaffold a resumable task-hypergraph workspace on disk.
#
# Creates the on-disk graph (config.json, topology, GOAL/STATUS/FINDINGS/REVIEW)
# plus nodes/ and maps/ subdirectories, and copies the companion scripts
# (validate.js, frontier.py, char_guard.py) next to the graph so the workspace
# is self-contained and resumable.
#
# The LAST line printed to stdout is always the resolved root path, so callers
# can capture it with:  ROOT="$(scaffold.sh ... | tail -n1)"
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Locate this script's own directory so we can copy the companion scripts that
# live next to it into the freshly scaffolded workspace.
# ---------------------------------------------------------------------------
DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

PROG="scaffold.sh"

# ---------------------------------------------------------------------------
# Defaults (the config-schema defaults; each is overridable by a flag).
# ---------------------------------------------------------------------------
MODE="tmpdir"          # tmpdir | in-repo | inline
FORMAT="html"          # topology is always HTML (legacy json|md accepted as no-op)
PROJECT=""             # defaults to basename of CWD
ARC="main"
ROOT_FLAG=""           # explicit --root
FORCE=0
GOAL_BUDGET=4000
NODE_BUDGET=2000
FINDINGS_BUDGET=4000
REVIEW_BUDGET=4000
MAX_PARALLEL=448     # dispatch up to this many ready nodes per wave (advisory)
AUTOSTART="full-auto"        # full-auto | gate-once | per-wave
FRONTIER_MODE="stream"       # stream | waves
REVIEW_PERSONA="skeptic"     # skeptic | brutalist | security | layered
REVIEW_SKEPTICS="3"
AUTONOMY="manual"            # manual | stop-hook
EXECUTOR="claude"            # claude | codex  (who runs the DO stage)
CODEX_MODEL="gpt-5.5"        # codex model slug when EXECUTOR=codex

COMPANIONS=(validate.py frontier.py char_guard.py codex_exec.sh)
ASSETS="$(cd "$DIR/.." 2>/dev/null && pwd)/assets"

usage() {
  cat <<EOF
$PROG - scaffold a resumable task-hypergraph workspace.

Usage:
  $PROG [options]

Options:
  --project NAME      project name (default: basename of CWD)
  --arc NAME          arc / branch name within the project (default: main)
  --mode MODE         tmpdir | in-repo | inline (default: tmpdir)
                        tmpdir   root = \${TMPDIR:-/tmp}/<project>_hypergraph
                        in-repo  requires --root (graph committed alongside code)
                        inline   prints a note and skips on-disk creation
  --root PATH         explicit workspace root (required for --mode in-repo)
  --max-parallel N    frontier max parallel nodes per wave (default: $MAX_PARALLEL)
  --goal-budget N     GOAL.md character budget (default: $GOAL_BUDGET)
  --node-budget N     per-node character budget (default: $NODE_BUDGET)
  --force             overwrite an existing non-empty topology
  -h, --help          show this help and exit

Behavior:
  Creates <root>/, <root>/nodes/, <root>/maps/ and writes topology.html (the
  authoritative graph AND its own rendered view — open it in a browser to see
  the hypergraph; config is folded into <meta name="th:*"> tags), GOAL.md,
  FINDINGS.md and REVIEW.md, then copies ${COMPANIONS[*]} next to the graph.
  Node status lives in topology.html (data-status); there is no STATUS.md.

  Refuses to clobber a populated topology unless --force is given.

  The last line written to stdout is the resolved root path.

Exit codes:
  0  success
  1  runtime error (refused overwrite, missing --root for in-repo, etc.)
  2  usage error (unknown flag, bad value)
EOF
}

err() { printf '%s: error: %s\n' "$PROG" "$*" >&2; }
note() { printf '%s: %s\n' "$PROG" "$*" >&2; }

die_usage() {
  err "$*"
  printf "Try '%s --help' for usage.\n" "$PROG" >&2
  exit 2
}

require_value() {
  # require_value <flag> <value-or-empty>
  if [ -z "${2:-}" ]; then
    die_usage "option '$1' requires a value"
  fi
}

require_int() {
  # require_int <flag> <value>
  case "$2" in
    ''|*[!0-9]*) die_usage "option '$1' requires a non-negative integer (got '${2:-}')" ;;
  esac
}

# ---------------------------------------------------------------------------
# Parse arguments.
# ---------------------------------------------------------------------------
while [ "$#" -gt 0 ]; do
  case "$1" in
    --project)      require_value "$1" "${2:-}"; PROJECT="$2"; shift 2 ;;
    --project=*)    PROJECT="${1#*=}"; shift ;;
    --arc)          require_value "$1" "${2:-}"; ARC="$2"; shift 2 ;;
    --arc=*)        ARC="${1#*=}"; shift ;;
    --mode)         require_value "$1" "${2:-}"; MODE="$2"; shift 2 ;;
    --mode=*)       MODE="${1#*=}"; shift ;;
    --root)         require_value "$1" "${2:-}"; ROOT_FLAG="$2"; shift 2 ;;
    --root=*)       ROOT_FLAG="${1#*=}"; shift ;;
    --format)       require_value "$1" "${2:-}"; FORMAT="$2"; shift 2 ;;
    --format=*)     FORMAT="${1#*=}"; shift ;;
    --max-parallel) require_value "$1" "${2:-}"; require_int "$1" "$2"; MAX_PARALLEL="$2"; shift 2 ;;
    --max-parallel=*) MAX_PARALLEL="${1#*=}"; require_int "--max-parallel" "$MAX_PARALLEL"; shift ;;
    --goal-budget)  require_value "$1" "${2:-}"; require_int "$1" "$2"; GOAL_BUDGET="$2"; shift 2 ;;
    --goal-budget=*) GOAL_BUDGET="${1#*=}"; require_int "--goal-budget" "$GOAL_BUDGET"; shift ;;
    --node-budget)  require_value "$1" "${2:-}"; require_int "$1" "$2"; NODE_BUDGET="$2"; shift 2 ;;
    --node-budget=*) NODE_BUDGET="${1#*=}"; require_int "--node-budget" "$NODE_BUDGET"; shift ;;
    --executor)     require_value "$1" "${2:-}"; EXECUTOR="$2"; shift 2 ;;
    --executor=*)   EXECUTOR="${1#*=}"; shift ;;
    --codex-model)  require_value "$1" "${2:-}"; CODEX_MODEL="$2"; shift 2 ;;
    --codex-model=*) CODEX_MODEL="${1#*=}"; shift ;;
    --force)        FORCE=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    --)             shift; break ;;
    -*)             die_usage "unknown option '$1'" ;;
    *)              die_usage "unexpected argument '$1'" ;;
  esac
done

# ---------------------------------------------------------------------------
# Validate enum-valued options.
# ---------------------------------------------------------------------------
case "$MODE" in
  tmpdir|in-repo|inline) ;;
  *) die_usage "invalid --mode '$MODE' (expected tmpdir | in-repo | inline)" ;;
esac

# Topology is always HTML now. Accept legacy --format json|md|html as a no-op
# alias (with a note) so old muscle memory does not hard-error.
case "$FORMAT" in
  html) ;;
  json|md) note "--format '$FORMAT' is deprecated; topology is always HTML." ; FORMAT="html" ;;
  *) die_usage "invalid --format '$FORMAT' (topology is always html)" ;;
esac

case "$EXECUTOR" in
  claude|codex) ;;
  *) die_usage "invalid --executor '$EXECUTOR' (expected claude | codex)" ;;
esac

# ---------------------------------------------------------------------------
# Derive project name and a filesystem-safe slug for the default tmpdir path.
# ---------------------------------------------------------------------------
if [ -z "$PROJECT" ]; then
  PROJECT="$(basename "$PWD")"
fi
if [ -z "$PROJECT" ] || [ "$PROJECT" = "/" ]; then
  PROJECT="project"
fi

# slug: lowercase-ish, non [A-Za-z0-9._-] -> _
SLUG="$(printf '%s' "$PROJECT" | tr -c 'A-Za-z0-9._-' '_' )"
[ -n "$SLUG" ] || SLUG="project"

# ---------------------------------------------------------------------------
# Resolve the workspace root according to mode.
# ---------------------------------------------------------------------------
to_abs() {
  # Echo an absolute path for $1 without requiring it to exist.
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *)  printf '%s/%s\n' "$PWD" "$1" ;;
  esac
}

DEFAULT_TMP_ROOT="${TMPDIR:-/tmp}"
# Strip any trailing slash from TMPDIR so we don't produce a double slash.
DEFAULT_TMP_ROOT="${DEFAULT_TMP_ROOT%/}"
DEFAULT_TMP_ROOT="${DEFAULT_TMP_ROOT}/${SLUG}_hypergraph"

case "$MODE" in
  tmpdir)
    if [ -n "$ROOT_FLAG" ]; then
      ROOT="$(to_abs "$ROOT_FLAG")"
    else
      ROOT="$DEFAULT_TMP_ROOT"
    fi
    ;;
  in-repo)
    if [ -z "$ROOT_FLAG" ]; then
      err "--mode in-repo requires --root <path>"
      exit 1
    fi
    ROOT="$(to_abs "$ROOT_FLAG")"
    ;;
  inline)
    if [ -n "$ROOT_FLAG" ]; then
      ROOT="$(to_abs "$ROOT_FLAG")"
    else
      ROOT="$DEFAULT_TMP_ROOT"
    fi
    ;;
esac

CREATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ---------------------------------------------------------------------------
# Inline mode: announce and skip all on-disk creation. Root path is still the
# final stdout line so callers have a stable contract.
# ---------------------------------------------------------------------------
if [ "$MODE" = "inline" ]; then
  note "inline mode: keeping the topology inline; no directories or files created."
  note "notional root would have been: $ROOT"
  printf '%s\n' "$ROOT"
  exit 0
fi

# ---------------------------------------------------------------------------
# Topology target + emptiness guard (HTML is the authoritative format).
# ---------------------------------------------------------------------------
TOPO="$ROOT/topology.html"

# topology_is_populated FILE -> exit 0 if it holds at least one real node.
# Uses the stdlib HTML parser so the schema-example in the template comment
# (which mentions class="node" inside <!-- ... -->) is NOT miscounted.
topology_is_populated() {
  local f="$1"
  [ -f "$f" ] || return 1
  F="$f" python3 - <<'PY'
import os, sys
from html.parser import HTMLParser
class P(HTMLParser):
    n = 0
    def handle_starttag(self, tag, attrs):
        a = {k: (v or "") for k, v in attrs}
        if "node" in a.get("class", "").split():
            self.n += 1
try:
    with open(os.environ["F"], "r", encoding="utf-8") as fh:
        p = P(); p.feed(fh.read())
except Exception:
    sys.exit(0)  # unreadable: treat as populated so we never silently clobber
sys.exit(0 if p.n > 0 else 1)
PY
}

if topology_is_populated "$TOPO"; then
  if [ "$FORCE" -ne 1 ]; then
    err "refusing to overwrite populated topology: $TOPO"
    err "re-run with --force to overwrite, or pick a different --root."
    exit 1
  fi
  note "overwriting populated topology (--force): $TOPO"
fi

# ---------------------------------------------------------------------------
# Create the directory skeleton.
# ---------------------------------------------------------------------------
mkdir -p "$ROOT" "$ROOT/nodes" "$ROOT/maps"
note "workspace root: $ROOT"

# ---------------------------------------------------------------------------
# topology.html — the authoritative graph AND its own rendered view. Config is
# folded into <meta name="th:*"> tags (no separate config.json). Substituted
# from the bundled self-rendering template.
# ---------------------------------------------------------------------------
TPL="$ASSETS/topology.template.html"
[ -f "$TPL" ] || { err "missing template: $TPL"; exit 1; }
TH_PROJECT="$PROJECT" TH_ARC="$ARC" TH_CREATED="$CREATED" \
TH_AUTOSTART="$AUTOSTART" TH_FRONTIER_MODE="$FRONTIER_MODE" \
TH_REVIEW_PERSONA="$REVIEW_PERSONA" TH_REVIEW_SKEPTICS="$REVIEW_SKEPTICS" \
TH_AUTONOMY="$AUTONOMY" TH_MAX_PARALLEL="$MAX_PARALLEL" TH_GOAL_BUDGET="$GOAL_BUDGET" \
TH_EXECUTOR="$EXECUTOR" TH_CODEX_MODEL="$CODEX_MODEL" \
TH_TPL="$TPL" TH_OUT="$TOPO" python3 - <<'PY'
import os
sub = {
    "{{PROJECT}}": os.environ["TH_PROJECT"],
    "{{ARC}}": os.environ["TH_ARC"],
    "{{CREATED}}": os.environ["TH_CREATED"],
    "{{AUTOSTART}}": os.environ["TH_AUTOSTART"],
    "{{FRONTIER_MODE}}": os.environ["TH_FRONTIER_MODE"],
    "{{REVIEW_PERSONA}}": os.environ["TH_REVIEW_PERSONA"],
    "{{REVIEW_SKEPTICS}}": os.environ["TH_REVIEW_SKEPTICS"],
    "{{AUTONOMY}}": os.environ["TH_AUTONOMY"],
    "{{EXECUTOR}}": os.environ["TH_EXECUTOR"],
    "{{CODEX_MODEL}}": os.environ["TH_CODEX_MODEL"],
    "{{MAX_PARALLEL}}": os.environ["TH_MAX_PARALLEL"],
    "{{GOAL_BUDGET}}": os.environ["TH_GOAL_BUDGET"],
}
html = open(os.environ["TH_TPL"], encoding="utf-8").read()
for k, v in sub.items():
    html = html.replace(k, v)
open(os.environ["TH_OUT"], "w", encoding="utf-8").write(html)
PY
note "wrote topology.html"

# ---------------------------------------------------------------------------
# GOAL.md — copied from the bundled drive-prompt template (Phase A fills it).
# Status lives in topology.html (data-status per node) — no separate STATUS.md.
# ---------------------------------------------------------------------------
if [ -f "$ASSETS/GOAL.template.md" ]; then
  cp "$ASSETS/GOAL.template.md" "$ROOT/GOAL.md"
else
  printf '# Goal\n\n## Objective\n\n{{OBJECTIVE}}\n' > "$ROOT/GOAL.md"
fi
note "wrote GOAL.md (budget ${GOAL_BUDGET} chars; gate with char_guard.py)"

# ---------------------------------------------------------------------------
# Empty FINDINGS.md and REVIEW.md (heading only).
# ---------------------------------------------------------------------------
printf '# Findings\n' > "$ROOT/FINDINGS.md"
printf '# Review\n' > "$ROOT/REVIEW.md"
note "wrote FINDINGS.md, REVIEW.md"

# ---------------------------------------------------------------------------
# Copy companion scripts next to the graph so the workspace is self-contained.
# ---------------------------------------------------------------------------
for companion in "${COMPANIONS[@]}"; do
  src="$DIR/$companion"
  if [ -f "$src" ]; then
    cp "$src" "$ROOT/$companion"
    note "copied $companion"
  else
    note "warning: companion not found, skipped: $src"
  fi
done

# ---------------------------------------------------------------------------
# Final contract: the resolved root path is the LAST stdout line.
# ---------------------------------------------------------------------------
printf '%s\n' "$ROOT"
