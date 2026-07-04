#!/usr/bin/env bash
# coverage-threshold.sh — verifier: test coverage is at or above THRESHOLD%.
#
# Contract: exits 0 = pass, non-zero = fail. Runs in under 30 seconds.
# No human judgment. Tests the outcome (coverage number), not the process.
#
# Why this exists: a coverage floor is the cheap anti-cheat companion to
# test-pass.sh. Deleting failing tests turns the suite green — and drops
# coverage. Pair the two and that move stops working.
#
# Adapt: set COVERAGE_CMD and THRESHOLD.
#   jest/istanbul:  COVERAGE_CMD="npx jest --coverage --coverageReporters=text-summary"
#   coverage.py:    COVERAGE_CMD="coverage run -m pytest -q && coverage report"
#
# Loop hookup:
#   until bash verifiers/templates/coverage-threshold.sh; do
#     claude -p "Raise test coverage to 80%. Verifier: bash verifiers/templates/coverage-threshold.sh"
#   done

set -uo pipefail

# ── CONFIG ── EDIT ME ────────────────────────────────────────────────────
COVERAGE_CMD="${COVERAGE_CMD:-}"   # required — see examples above
THRESHOLD="${THRESHOLD:-80}"       # minimum percent, integer or decimal
# ─────────────────────────────────────────────────────────────────────────

[ -n "$COVERAGE_CMD" ] || { echo "FAIL: set COVERAGE_CMD"; exit 2; }

OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT

echo "verifier: $COVERAGE_CMD (coverage >= ${THRESHOLD}%)"
if ! eval "$COVERAGE_CMD" >"$OUT" 2>&1; then
  echo "FAIL: coverage command exited non-zero — last 20 lines:"
  tail -n 20 "$OUT"
  exit 1
fi

# Extraction — the two common formats, first hit wins. Edit if yours differs.
#   coverage.py `coverage report`:   "TOTAL    142    12    92%"
#   istanbul/jest text-summary:      "Statements   : 85.71% ( 12/14 )"
#   istanbul/jest text table:        "All files    |   85.71 |   ..."
PCT=$(awk '/^TOTAL/ { gsub(/%/, "", $NF); print $NF; exit }' "$OUT")
if [ -z "$PCT" ]; then
  PCT=$(awk -F'[:%]' '/^Statements/ { gsub(/ /, "", $2); print $2; exit }' "$OUT")
fi
if [ -z "$PCT" ]; then
  PCT=$(awk -F'|' '/^All files/ { gsub(/ /, "", $2); print $2; exit }' "$OUT")
fi

if [ -z "$PCT" ]; then
  echo "FAIL: could not extract a coverage percentage — edit the extraction block. Last 20 lines:"
  tail -n 20 "$OUT"
  exit 2
fi

# Integer/decimal compare via awk — no bc dependency.
if awk -v got="$PCT" -v want="$THRESHOLD" 'BEGIN { exit (got + 0 >= want + 0) ? 0 : 1 }'; then
  echo "PASS: coverage ${PCT}% >= required ${THRESHOLD}%"
  exit 0
fi

echo "FAIL: coverage ${PCT}% < required ${THRESHOLD}%"
exit 1
