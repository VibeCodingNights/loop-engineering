#!/usr/bin/env bash
# composite.sh — AND-combinator: every verifier in the list must pass.
#
# Contract: exits 0 = pass (all checks green), non-zero = fail. Keep the
# whole chain under 30 seconds. No human judgment. Tests outcomes.
#
# One dimension is never enough overnight. Tests pass AND types clean AND
# the diff stays small. An agent can game any single check; gaming three
# orthogonal checks at once is much harder.
#
# Adapt: list your verifier commands in VERIFIERS, cheapest first — the
# combinator short-circuits on the first failure. Each entry is a full
# command line (bash script, python script, anything that exits 0/1).
#
# Diff budget (optional anti-cheat): set MAX_DIFF_LINES to fail when the
# working tree has drifted more than N changed lines from BASE_REF. This
# is what catches the 3 a.m. 4,000-line "refactor" nobody asked for.
#
# Loop hookup:
#   until bash verifiers/templates/composite.sh; do
#     claude -p "…your goal… Verifier: bash verifiers/templates/composite.sh"
#   done

set -uo pipefail

# ── CONFIG ── EDIT ME ────────────────────────────────────────────────────
VERIFIERS=(
  "bash verifiers/templates/test-pass.sh"
  "bash verifiers/templates/type-check.sh"
)
MAX_DIFF_LINES="${MAX_DIFF_LINES:-}"   # e.g. 500. Empty = diff budget off.
BASE_REF="${BASE_REF:-HEAD}"           # ref the diff budget measures against
# ─────────────────────────────────────────────────────────────────────────

failed=""

# Diff budget runs first — it is the cheapest check.
if [ -n "$MAX_DIFF_LINES" ]; then
  changed=$(git diff --numstat "$BASE_REF" -- 2>/dev/null | awk '{ a += $1 + $2 } END { print a + 0 }')
  if [ "${changed:-0}" -gt "$MAX_DIFF_LINES" ]; then
    echo " ✗ diff budget — $changed changed lines vs $BASE_REF (max $MAX_DIFF_LINES)"
    failed="diff budget"
  else
    echo " ✓ diff budget — $changed changed lines vs $BASE_REF (max $MAX_DIFF_LINES)"
  fi
fi

for v in "${VERIFIERS[@]}"; do
  if [ -n "$failed" ]; then
    echo " · $v (skipped)"
    continue
  fi
  if out=$(eval "$v" 2>&1); then
    echo " ✓ $v"
  else
    echo " ✗ $v"
    printf '%s\n' "$out" | head -n 15 | sed 's/^/   | /'
    failed="$v"
  fi
done

if [ -n "$failed" ]; then
  echo "FAIL: composite stopped at: $failed"
  exit 1
fi

echo "PASS: all checks green"
exit 0
