#!/usr/bin/env bash
# snapshot-diff.sh — verifier: generated output matches the golden snapshot.
#
# Contract: exits 0 = pass, non-zero = fail. Runs in under 30 seconds.
# No human judgment. Tests the outcome (bytes match), not the process.
#
# Adapt: set GENERATE_CMD, OUTPUT_PATH, GOLDEN_PATH. Works on a single
# file or a whole directory (diff -ru handles both).
#
# WARNING — the escape hatch: UPDATE_SNAPSHOT=1 re-blesses the golden copy
# from current output. The agent must NEVER be able to run that. Keep
# golden files outside the tree your loop can write — another directory,
# another repo, or chmod -R a-w. An agent that can update the snapshot
# will "fix" failures by re-blessing its own broken output. That is the
# model grading its own work.
#
# Loop hookup:
#   until bash verifiers/templates/snapshot-diff.sh; do
#     claude -p "Make the renderer output match the golden snapshot. Verifier: bash verifiers/templates/snapshot-diff.sh"
#   done

set -uo pipefail

# ── CONFIG ── EDIT ME ────────────────────────────────────────────────────
GENERATE_CMD="${GENERATE_CMD:-}"      # e.g. "node scripts/render.js > out/page.html"
OUTPUT_PATH="${OUTPUT_PATH:-out}"     # file or directory GENERATE_CMD produces
GOLDEN_PATH="${GOLDEN_PATH:-golden}"  # blessed snapshot — keep it OUTSIDE the loop's writable tree
# ─────────────────────────────────────────────────────────────────────────

[ -n "$GENERATE_CMD" ] || { echo "FAIL: set GENERATE_CMD"; exit 2; }

if ! eval "$GENERATE_CMD"; then
  echo "FAIL: generate command exited non-zero"
  exit 1
fi
[ -e "$OUTPUT_PATH" ] || { echo "FAIL: GENERATE_CMD did not produce $OUTPUT_PATH"; exit 1; }

if [ "${UPDATE_SNAPSHOT:-0}" = "1" ]; then
  # Human-only path. Re-blesses the golden copy from current output.
  case "$GOLDEN_PATH" in ""|"/"|".") echo "FAIL: refusing to re-bless GOLDEN_PATH='$GOLDEN_PATH'"; exit 2;; esac
  rm -rf "$GOLDEN_PATH"
  cp -R "$OUTPUT_PATH" "$GOLDEN_PATH"
  echo "SNAPSHOT UPDATED: $GOLDEN_PATH re-blessed from $OUTPUT_PATH."
  echo "If an agent just ran this, your verifier is compromised. Move the golden files out of its reach."
  exit 0
fi

if [ ! -e "$GOLDEN_PATH" ]; then
  echo "FAIL: no golden snapshot at $GOLDEN_PATH."
  echo "A human blesses the first one: UPDATE_SNAPSHOT=1 bash $0"
  exit 2
fi

DIFF=$(mktemp)
trap 'rm -f "$DIFF"' EXIT

if diff -ru "$GOLDEN_PATH" "$OUTPUT_PATH" >"$DIFF" 2>&1; then
  echo "PASS: output matches golden snapshot ($GOLDEN_PATH)"
  exit 0
fi

echo "FAIL: output diverges from golden snapshot — first 40 diff lines:"
head -n 40 "$DIFF"
echo "(full diff: diff -ru $GOLDEN_PATH $OUTPUT_PATH)"
exit 1
