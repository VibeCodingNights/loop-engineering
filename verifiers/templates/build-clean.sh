#!/usr/bin/env bash
# build-clean.sh — verifier: the build succeeds and emits zero warnings.
#
# Contract: exits 0 = pass, non-zero = fail. Runs in under 30 seconds.
# No human judgment. Tests the outcome (clean build), not the process.
#
# Why warnings count: "exit 0" alone lets an agent ship a build that works
# with 200 deprecation warnings. Warnings are where drift hides. This
# script fails on both a broken build and a noisy one.
#
# Adapt: set BUILD_CMD. Tighten WARN_PATTERN if your toolchain prints
# harmless lines containing "warning" (e.g. "0 warnings generated").
#
# Loop hookup:
#   until bash verifiers/templates/build-clean.sh; do
#     claude -p "Make the build pass with zero warnings. Verifier: bash verifiers/templates/build-clean.sh"
#   done

set -uo pipefail

# ── CONFIG ── EDIT ME ────────────────────────────────────────────────────
BUILD_CMD="${BUILD_CMD:-npm run build}"   # your build command
WARN_PATTERN="${WARN_PATTERN:-warning}"   # extended regex, matched case-insensitively
# ─────────────────────────────────────────────────────────────────────────

OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT

echo "verifier: $BUILD_CMD (no lines matching /$WARN_PATTERN/i)"
if ! eval "$BUILD_CMD" >"$OUT" 2>&1; then
  echo "FAIL: build command exited non-zero — last 20 lines:"
  tail -n 20 "$OUT"
  exit 1
fi

warnings=$(grep -iE -e "$WARN_PATTERN" "$OUT" || true)
if [ -n "$warnings" ]; then
  count=$(printf '%s\n' "$warnings" | wc -l | tr -d ' ')
  echo "FAIL: build succeeded but emitted $count warning lines — first 5:"
  printf '%s\n' "$warnings" | head -n 5
  exit 1
fi

echo "PASS: build clean — exit 0, zero warning lines"
exit 0
