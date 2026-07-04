#!/usr/bin/env bash
# type-check.sh — verifier: the type checker reports zero errors.
#
# Contract: exits 0 = pass, non-zero = fail. Runs in under 30 seconds.
# No human judgment. Tests the outcome (types clean), not the process.
#
# Adapt: set TYPECHECK_CMD explicitly, or leave it empty to autodetect
# tsc / pyright / mypy from the files in your project root.
#
# Loop hookup:
#   until bash verifiers/templates/type-check.sh; do
#     claude -p "Fix every type error. Verifier: bash verifiers/templates/type-check.sh"
#   done

set -uo pipefail

# ── CONFIG ── EDIT ME ────────────────────────────────────────────────────
TYPECHECK_CMD="${TYPECHECK_CMD:-}"   # empty = autodetect below
# ─────────────────────────────────────────────────────────────────────────

if [ -z "$TYPECHECK_CMD" ]; then
  if [ -f tsconfig.json ]; then
    TYPECHECK_CMD="npx tsc --noEmit"
  elif [ -f pyrightconfig.json ]; then
    if command -v pyright >/dev/null 2>&1; then
      TYPECHECK_CMD="pyright"
    else
      TYPECHECK_CMD="npx pyright"
    fi
  elif [ -f mypy.ini ] || { [ -f pyproject.toml ] && grep -q '\[tool\.mypy\]' pyproject.toml; }; then
    TYPECHECK_CMD="mypy ."
  else
    echo "FAIL: could not autodetect a type checker — set TYPECHECK_CMD"
    exit 2
  fi
fi

OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT

echo "verifier: $TYPECHECK_CMD"
if eval "$TYPECHECK_CMD" >"$OUT" 2>&1; then
  echo "PASS: type check clean"
  exit 0
fi

echo "FAIL: type errors — first 20 lines:"
head -n 20 "$OUT"
exit 1
