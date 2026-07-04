#!/usr/bin/env bash
#
# 01 — THE RALPH LOOP
#
# The original hack. Geoffrey Huntley put `claude -p` inside `while true`,
# named it after Ralph Wiggum, and left one running for three months on a
# single prompt. It came back with a compiled programming language — LLVM
# backend and all. $297 in API costs against an estimated $50,000 of
# developer time. In that language, `slay` means `func` and `yeet` means
# `import`.
#
# The core loop is three lines. You can read and understand the entire thing:
#
#     while true; do
#       claude -p "$(cat PROMPT.md)" --allowedTools "..."
#       sleep 5
#     done
#
# Each iteration starts a fresh session with zero memory of the last one.
# The loop's only memory is the repo itself: files, commits, and notes the
# agent leaves for its next self. Your PROMPT_FILE should tell it to commit
# progress and read its own trail.
#
# Two knobs matter:
#
#   PROMPT_FILE   The task, restated every iteration. Include the exit
#                 condition in it ("run ./verifier.sh; if it exits 0 you
#                 are done") so the agent aims at the same target the loop
#                 checks.
#   VERIFIER      A script that exits 0 when the work is actually done.
#                 The loop is easy. This is the whole game. Copy one from
#                 ../verifiers/templates/ and edit it for your project.
#
# Everything else in this file is a seatbelt, so the script is safe to run
# as written: it stops the moment the verifier passes, MAX_ITERATIONS is a
# hard ceiling when it never does, and each iteration carries its own
# dollar cap.

set -euo pipefail

# --- Config: edit these for your project -------------------------------------

PROMPT_FILE="${PROMPT_FILE:-PROMPT.md}"   # what the agent is told, every time
VERIFIER="${VERIFIER:-./verifier.sh}"     # exits 0 = done, non-zero = not yet
MAX_ITERATIONS="${MAX_ITERATIONS:-25}"    # hard stop even if the verifier never passes
SLEEP_SECONDS="${SLEEP_SECONDS:-5}"       # breathing room between iterations

# Per-iteration dollar cap (only works with -p/--print, which is what we use).
# Worst case for the whole run = MAX_ITERATIONS x this. 25 x $0.50 = $12.50.
BUDGET_PER_ITERATION="${BUDGET_PER_ITERATION:-0.50}"

# Tools the agent may use without asking. One quoted string, space-separated,
# exactly as `claude --help` documents it. Scope Bash patterns tightly.
# The original Ralph ran with permissions off entirely. You don't have to.
ALLOWED_TOOLS="${ALLOWED_TOOLS:-Edit Write Bash(git *) Bash(npm *)}"

# --- Preflight ----------------------------------------------------------------

if [ ! -f "$PROMPT_FILE" ]; then
  echo "No $PROMPT_FILE. Write the task there first — include the exit condition." >&2
  exit 1
fi

if [ ! -f "$VERIFIER" ]; then
  echo "No verifier at $VERIFIER. Copy one from ../verifiers/templates/ and edit it." >&2
  exit 1
fi

# Already done? Spend nothing.
if bash "$VERIFIER"; then
  echo "Verifier already passes. Nothing to do."
  exit 0
fi

# --- The loop -------------------------------------------------------------------

i=0
while true; do
  i=$((i + 1))
  if [ "$i" -gt "$MAX_ITERATIONS" ]; then
    echo "Hit MAX_ITERATIONS=$MAX_ITERATIONS and the verifier still fails." >&2
    echo "Read the last output before raising the cap — the prompt or the verifier is wrong." >&2
    exit 1
  fi
  echo "--- ralph iteration $i/$MAX_ITERATIONS ---"

  # This line is the entire idea. Fresh agent, same prompt, non-interactive.
  # `|| true` so one failed API call doesn't kill the loop under `set -e`.
  claude -p "$(cat "$PROMPT_FILE")" --allowedTools "$ALLOWED_TOOLS" --max-budget-usd "$BUDGET_PER_ITERATION" || true

  # Exit condition. Mechanical. No judgment. The agent never grades itself.
  if bash "$VERIFIER"; then
    echo "Verifier passed after $i iteration(s). Done."
    exit 0
  fi

  sleep "$SLEEP_SECONDS"
done

# FAILURE MODES
# - Verifier that always passes: the loop exits after one iteration with the
#   work half done. Run `bash verifier.sh; echo $?` on a broken repo first —
#   it must print non-zero.
# - Verifier that never passes: the loop burns all 25 iterations. That is
#   what MAX_ITERATIONS is for. Tighten the prompt, not the cap.
# - No committed progress: each iteration wakes with amnesia. If the prompt
#   doesn't say "commit what you did," iteration 12 redoes iteration 3.
# - Cost: caps here are per-process. Set a provider spending limit too —
#   see ../safety/cost-caps.md before running this overnight.
#
# WHERE NEXT
# - ../verifiers/templates/  — copy-paste verifiers: test-pass, type-check,
#   no-pattern, composite. Edit one; that's your VERIFIER.
# - ../verifiers/good-vs-bad.md — is your goal mechanically checkable at all?
# - 02-slash-loop.md — the same idea as one command inside Claude Code.
# - 03-slash-goal.md — a separate model makes the done/not-done call.
#
# Flags verified against Claude Code 2.1.201 (`claude --help`) on macOS.
