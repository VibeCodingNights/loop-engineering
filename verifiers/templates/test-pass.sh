#!/usr/bin/env bash
# test-pass.sh — verifier: the test suite passes.
#
# Contract: exits 0 = pass, non-zero = fail. Runs in under 30 seconds.
# No human judgment. Tests the outcome (suite green), not the process.
#
# Adapt: set TEST_CMD to your runner, or leave it empty to autodetect.
# Anti-cheat: set MIN_TESTS. Agents under pressure delete failing tests —
# a green suite with 3 tests where you had 40 is not a pass. MIN_TESTS
# fails the run if the runner reports fewer passing tests than that.
#
# Loop hookup:
#   until bash verifiers/templates/test-pass.sh; do
#     claude -p "Make the tests pass. Do not delete or skip tests. Verifier: bash verifiers/templates/test-pass.sh"
#   done

set -uo pipefail

# ── CONFIG ── EDIT ME ────────────────────────────────────────────────────
TEST_CMD="${TEST_CMD:-}"      # empty = autodetect below
MIN_TESTS="${MIN_TESTS:-0}"   # fail if fewer passing tests than this. 0 = off.
# ─────────────────────────────────────────────────────────────────────────

if [ -z "$TEST_CMD" ]; then
  if   [ -f package.json ];   then TEST_CMD="npm test"
  elif [ -f pyproject.toml ] || [ -f pytest.ini ]; then TEST_CMD="pytest -q"
  elif [ -f Cargo.toml ];     then TEST_CMD="cargo test"
  elif [ -f go.mod ];         then TEST_CMD="go test ./..."
  else
    echo "FAIL: could not autodetect a test runner — set TEST_CMD"
    exit 2
  fi
fi

OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT

echo "verifier: $TEST_CMD"
if ! eval "$TEST_CMD" >"$OUT" 2>&1; then
  echo "FAIL: test command exited non-zero — last 20 lines:"
  tail -n 20 "$OUT"
  exit 1
fi

if [ "$MIN_TESTS" -gt 0 ]; then
  # Heuristic count: largest "N passed" in the summary (pytest, jest, cargo),
  # or the number of "--- PASS" lines (go — needs `go test -v` to print them).
  # Jest also prints "Test Suites: N passed"; taking the max keeps the larger
  # per-test number. Edit this block if your runner reports differently.
  count=0
  while read -r n; do
    [ "$n" -gt "$count" ] && count=$n
  done < <(grep -Eo '[0-9]+ passed' "$OUT" | grep -Eo '^[0-9]+' || true)
  go_count=$(grep -c -- '--- PASS' "$OUT" 2>/dev/null || true)
  [ "${go_count:-0}" -gt "$count" ] && count=$go_count

  if [ "$count" -lt "$MIN_TESTS" ]; then
    echo "FAIL: suite is green but only $count passing tests reported (MIN_TESTS=$MIN_TESTS)."
    echo "Tests went missing. That is the agent deleting its way to green."
    exit 1
  fi
  echo "PASS: tests green, $count passing tests (>= $MIN_TESTS required)"
  exit 0
fi

echo "PASS: tests green"
exit 0
