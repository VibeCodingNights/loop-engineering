#!/usr/bin/env bash
#
# codex_exec.sh — adapter to drive the Codex CLI as a task-hypergraph EXECUTOR.
#
# This is the ONE place Codex flags live. `codex exec` and `codex exec resume`
# have DIVERGENT flag surfaces (resume rejects -s/--sandbox; you must use
# `-c sandbox_mode=...`), so every caller goes through here instead of
# re-deriving flags. The Workflow JS sandbox can't run shells, so a Bash-capable
# Claude leaf calls this; see the task-hypergraph SKILL.md.
#
# Usage:
#   codex_exec.sh [--model M] [--sandbox MODE] [--cd DIR] [--resume THREAD_ID]
#                 [--effort LEVEL] [--] "<prompt>"
#   # prompt may also be piped on stdin (omit the argument)
#
#   --model M        model slug (default: $CODEX_MODEL or gpt-5.5)
#   --sandbox MODE   read-only | workspace-write | danger-full-access
#                    (default: workspace-write — the executor writes code)
#   --cd DIR         working root for Codex (default: current directory)
#   --resume TID     resume a prior Codex thread (cross-cycle continuity)
#   --effort LEVEL   model_reasoning_effort (e.g. high); omit to use codex default
#
# Output (plain text, greppable) on success, exit 0:
#   thread_id: <uuid>
#   model: <slug>
#   tokens: <in>/<out>
#   --- message ---
#   <codex's final agent message>
#
# On a Codex error (usage limit, turn.failed, bad model, non-zero exit) it prints
# the error to stderr and exits 1 — callers MUST treat that as a failed build,
# never a silent pass.
set -euo pipefail

PROG="codex_exec.sh"
MODEL="${CODEX_MODEL:-gpt-5.5}"
SANDBOX="workspace-write"
CD=""
RESUME=""
EFFORT=""
PROMPT=""

err() { printf '%s: %s\n' "$PROG" "$*" >&2; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --model)   MODEL="$2"; shift 2 ;;
    --model=*) MODEL="${1#*=}"; shift ;;
    --sandbox)   SANDBOX="$2"; shift 2 ;;
    --sandbox=*) SANDBOX="${1#*=}"; shift ;;
    --cd)   CD="$2"; shift 2 ;;
    --cd=*) CD="${1#*=}"; shift ;;
    --resume)   RESUME="$2"; shift 2 ;;
    --resume=*) RESUME="${1#*=}"; shift ;;
    --effort)   EFFORT="$2"; shift 2 ;;
    --effort=*) EFFORT="${1#*=}"; shift ;;
    -h|--help) sed -n '3,33p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --) shift; PROMPT="${1:-}"; break ;;
    -*) err "unknown option '$1'"; exit 2 ;;
    *)  PROMPT="$1"; shift ;;
  esac
done

# Prompt from stdin if not given as an argument.
if [ -z "$PROMPT" ]; then
  if [ -t 0 ]; then err "no prompt (give an argument or pipe one on stdin)"; exit 2; fi
  PROMPT="$(cat)"
fi
[ -n "$PROMPT" ] || { err "empty prompt"; exit 2; }

command -v codex >/dev/null 2>&1 || { err "codex CLI not found on PATH"; exit 2; }

TMP="$(mktemp -t codex_exec.XXXXXX)"
trap 'rm -f "$TMP"' EXIT

# Build the argv. exec vs exec-resume diverge on the sandbox flag:
#   codex exec         -> -s/--sandbox MODE
#   codex exec resume  -> rejects -s; sandbox set via -c sandbox_mode="MODE"
ARGS=(exec --json -m "$MODEL" --skip-git-repo-check)
[ -n "$CD" ]     && ARGS+=(-C "$CD")
[ -n "$EFFORT" ] && ARGS+=(-c "model_reasoning_effort=\"$EFFORT\"")
if [ -n "$RESUME" ]; then
  ARGS=(exec resume "$RESUME" --json -m "$MODEL" --skip-git-repo-check -c "sandbox_mode=\"$SANDBOX\"")
  [ -n "$CD" ]     && ARGS+=(-C "$CD")
  [ -n "$EFFORT" ] && ARGS+=(-c "model_reasoning_effort=\"$EFFORT\"")
else
  ARGS+=(-s "$SANDBOX")
fi

# `< /dev/null` so codex never blocks on "Reading additional input from stdin".
if ! codex "${ARGS[@]}" "$PROMPT" </dev/null >"$TMP" 2>/dev/null; then
  : # codex exited non-zero; the JSONL (if any) still carries the reason — parse below.
fi

# Parse the JSONL transcript with the stdlib; emit a clean result or fail loudly.
MODEL="$MODEL" python3 - "$TMP" <<'PY'
import json, os, sys

tid = ""
msg = None
err_msg = None
tin = tout = 0
for line in open(sys.argv[1], encoding="utf-8"):
    line = line.strip()
    if not line:
        continue
    try:
        e = json.loads(line)
    except ValueError:
        continue
    t = e.get("type", "")
    if t == "thread.started":
        tid = e.get("thread_id", "")
    elif t == "turn.completed":
        u = e.get("usage", {}) or {}
        tin = u.get("input_tokens", 0) or 0
        tout = u.get("output_tokens", 0) or 0
    elif t == "item.completed":
        it = e.get("item", {}) or {}
        if it.get("type") == "agent_message":
            msg = it.get("text", "")
    elif t in ("error", "turn.failed"):
        m = e.get("message") or e.get("error")
        err_msg = m if isinstance(m, str) else json.dumps(m)

if err_msg or msg is None:
    sys.stderr.write("codex_exec.sh: codex turn failed: "
                     + (err_msg or "no agent_message in transcript") + "\n")
    sys.exit(1)

print(f"thread_id: {tid}")
print(f"model: {os.environ['MODEL']}")
print(f"tokens: {tin}/{tout}")
print("--- message ---")
print(msg)
PY
