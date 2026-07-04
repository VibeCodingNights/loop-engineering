#!/usr/bin/env bash
# no-pattern.sh — migration verifier: zero matches of the old pattern remain.
#
# Contract: exits 0 = pass, non-zero = fail. Runs in under 30 seconds.
# No human judgment. Tests the outcome (pattern gone), not the process.
#
# "Migrate off Express" is done when zero Express imports remain. That is
# mechanically checkable. This script is the check.
#
# Adapt: set PATTERN (extended regex), SEARCH_PATH, and optionally GLOB.
# Uses plain grep for portability. If you have ripgrep, this is equivalent
# (rg also exits 1 on no match, which is the PASS case here):
#   rg -n -g "$GLOB" -e "$PATTERN" "$SEARCH_PATH"
#
# Loop hookup:
#   until bash verifiers/templates/no-pattern.sh; do
#     claude -p "Remove every remaining Express import from src/. Verifier: bash verifiers/templates/no-pattern.sh"
#   done

set -uo pipefail   # no -e: grep exiting 1 (no match) is the PASS case

# ── CONFIG ── EDIT ME ────────────────────────────────────────────────────
PATTERN="${PATTERN:-express}"        # extended regex, e.g. "require\\('express'\\)"
SEARCH_PATH="${SEARCH_PATH:-src}"    # directory or file to scan
GLOB="${GLOB:-}"                     # optional filename filter, e.g. "*.ts"
# ─────────────────────────────────────────────────────────────────────────

[ -e "$SEARCH_PATH" ] || { echo "FAIL: SEARCH_PATH '$SEARCH_PATH' does not exist"; exit 2; }

grep_args=(-rnE --exclude-dir=.git)
[ -n "$GLOB" ] && grep_args+=(--include="$GLOB")

matches=$(grep "${grep_args[@]}" -e "$PATTERN" "$SEARCH_PATH" 2>/dev/null)
status=$?

if [ "$status" -eq 0 ]; then
  count=$(printf '%s\n' "$matches" | wc -l | tr -d ' ')
  echo "FAIL: $count matches of /$PATTERN/ remain in $SEARCH_PATH — first 5:"
  printf '%s\n' "$matches" | head -n 5
  [ "$count" -gt 5 ] && echo "  ... and $((count - 5)) more"
  exit 1
elif [ "$status" -eq 1 ]; then
  echo "PASS: zero matches of /$PATTERN/ in $SEARCH_PATH"
  exit 0
else
  echo "FAIL: grep errored (exit $status) — check PATTERN and SEARCH_PATH"
  exit 2
fi
