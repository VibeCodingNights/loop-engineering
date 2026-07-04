#!/usr/bin/env bash
# watchdog.sh — wraps a loop and kills it when a limit trips.
#
# Not a verifier — a circuit breaker. The verifier decides when the loop is
# done; the watchdog decides when it is dead. Run anything overnight
# without one and you are betting your API balance on nothing going wrong.
#
# Usage:
#   bash verifiers/watchdog.sh -- <loop command...>
#   bash verifiers/watchdog.sh -- bash patterns/01-ralph-loop.sh
#   MAX_RUNTIME_HOURS=6 MAX_IDLE_MINUTES=20 bash verifiers/watchdog.sh -- <loop command...>
#
# Kills the loop's whole process group when:
#   - runtime exceeds MAX_RUNTIME_HOURS
#   - no file changes under WATCH_DIR for MAX_IDLE_MINUTES — a loop that
#     stopped writing files has stalled, or is burning tokens on broken
#     tool calls (the 400-broken-tool-calls-in-5-minutes failure mode)
#   - spend reported by COST_CMD exceeds MAX_SPEND_USD
#
# Honest note on spend: API spend is not uniformly queryable from a shell.
# Neither Anthropic nor OpenAI expose a real-time cost endpoint you can hit
# without setup. COST_CMD is a hook: set it to any command that echoes the
# dollars spent so far as a bare number (e.g. a script parsing your
# provider's usage export). If it is unset, the spend check is skipped with
# a warning — and your real cap is the hard spending limit in the provider
# dashboard. Set that first. See safety/cost-caps.md.
#
# Exit codes: the wrapped loop's own exit code if it finishes; 3 if the
# watchdog tripped; 2 on usage error.

set -uo pipefail

# ── CONFIG ── EDIT ME (or override via env) ──────────────────────────────
MAX_RUNTIME_HOURS="${MAX_RUNTIME_HOURS:-8}"    # 0 = no runtime limit
MAX_IDLE_MINUTES="${MAX_IDLE_MINUTES:-30}"     # 0 = no idle limit
WATCH_DIR="${WATCH_DIR:-.}"                    # tree to watch for file changes (.git excluded)
MAX_SPEND_USD="${MAX_SPEND_USD:-20}"           # only enforced if COST_CMD is set
COST_CMD="${COST_CMD:-}"                       # command echoing dollars spent, e.g. "bash my-usage-parser.sh"
POLL_SECONDS="${POLL_SECONDS:-60}"
# ─────────────────────────────────────────────────────────────────────────

if [ "${1:-}" != "--" ] || [ $# -lt 2 ]; then
  echo "usage: $0 -- <loop command...>" >&2
  echo "  e.g. $0 -- bash patterns/01-ralph-loop.sh" >&2
  exit 2
fi
shift

SENTINEL=$(mktemp)
CHILD=""

kill_group() {
  # TERM the whole process group, wait, then KILL stragglers.
  kill -TERM -- "-$CHILD" 2>/dev/null || kill -TERM "$CHILD" 2>/dev/null || true
  sleep 2
  if kill -0 "$CHILD" 2>/dev/null; then
    kill -KILL -- "-$CHILD" 2>/dev/null || kill -KILL "$CHILD" 2>/dev/null || true
  fi
}

cleanup() {
  if [ -n "$CHILD" ] && kill -0 "$CHILD" 2>/dev/null; then
    kill_group
  fi
  rm -f "$SENTINEL"
}
trap cleanup EXIT
trap 'echo "watchdog: interrupted"; exit 130' INT
trap 'echo "watchdog: terminated"; exit 143' TERM

trip() {
  echo "WATCHDOG TRIPPED: $1"
  echo "watchdog: killing loop (pid $CHILD and its process group)"
  exit 3   # EXIT trap does the killing
}

# Launch the loop in its own process group so we can kill everything it
# spawned, not just the top process. setsid where available (Linux);
# elsewhere `set -m` makes bash give the background job its own group (macOS).
if command -v setsid >/dev/null 2>&1; then
  setsid "$@" &
  CHILD=$!
else
  set -m
  "$@" &
  CHILD=$!
  set +m
fi

START=$(date +%s)
LAST_CHANGE=$START
touch "$SENTINEL"
warned_no_cost=0
echo "watchdog: pid $CHILD | runtime cap ${MAX_RUNTIME_HOURS}h | idle cap ${MAX_IDLE_MINUTES}m on $WATCH_DIR | poll ${POLL_SECONDS}s"

while kill -0 "$CHILD" 2>/dev/null; do
  sleep "$POLL_SECONDS"
  kill -0 "$CHILD" 2>/dev/null || break
  now=$(date +%s)

  # 1. Runtime cap
  if awk -v h="$MAX_RUNTIME_HOURS" 'BEGIN { exit !(h > 0) }' \
     && awk -v e="$((now - START))" -v h="$MAX_RUNTIME_HOURS" 'BEGIN { exit !(e >= h * 3600) }'; then
    trip "runtime exceeded ${MAX_RUNTIME_HOURS}h"
  fi

  # 2. Idle cap — portable mtime scan: anything newer than the sentinel?
  #    (.git excluded: commits follow working-tree writes, so the tree is
  #    the honest progress signal.)
  changed=$(find "$WATCH_DIR" -name .git -prune -o -type f -newer "$SENTINEL" -print 2>/dev/null | head -n 1)
  if [ -n "$changed" ]; then
    touch "$SENTINEL"
    LAST_CHANGE=$now
  elif awk -v m="$MAX_IDLE_MINUTES" 'BEGIN { exit !(m > 0) }' \
       && awk -v i="$((now - LAST_CHANGE))" -v m="$MAX_IDLE_MINUTES" 'BEGIN { exit !(i >= m * 60) }'; then
    trip "no file changes under $WATCH_DIR for ${MAX_IDLE_MINUTES}m"
  fi

  # 3. Spend cap — only if a cost source is configured
  if [ -n "$COST_CMD" ]; then
    spend=$(eval "$COST_CMD" 2>/dev/null | head -n 1 | tr -d '$ ')
    case "$spend" in
      ''|*[!0-9.]*)
        echo "watchdog: WARN — COST_CMD did not return a number (got '$spend'), spend check skipped this poll"
        ;;
      *)
        if awk -v s="$spend" -v cap="$MAX_SPEND_USD" 'BEGIN { exit !(s >= cap) }'; then
          trip "spend \$$spend >= cap \$$MAX_SPEND_USD"
        fi
        ;;
    esac
  elif [ "$warned_no_cost" -eq 0 ]; then
    echo "watchdog: WARN — COST_CMD unset, spend check disabled. Set a hard spending limit in your provider dashboard (safety/cost-caps.md)."
    warned_no_cost=1
  fi
done

wait "$CHILD" 2>/dev/null
status=$?
echo "watchdog: loop exited on its own (exit $status) after $(( $(date +%s) - START ))s"
exit "$status"
