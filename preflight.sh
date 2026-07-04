#!/usr/bin/env bash
# preflight.sh — Loop Engineering setup check.
#
# Run it once when you sit down:
#   bash preflight.sh
#
# Four checks, under 60 seconds, no prompts. Fix what fails, rerun, go.

set -u

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
TOTAL_COUNT=0

ok() {
  TOTAL_COUNT=$((TOTAL_COUNT + 1)); PASS_COUNT=$((PASS_COUNT + 1))
  printf '[PASS] %s\n' "$1"
}

bad() {
  TOTAL_COUNT=$((TOTAL_COUNT + 1)); FAIL_COUNT=$((FAIL_COUNT + 1))
  printf '[FAIL] %s\n' "$1"
  if [ -n "${2:-}" ]; then printf '       fix: %s\n' "$2"; fi
}

warn() {
  TOTAL_COUNT=$((TOTAL_COUNT + 1)); WARN_COUNT=$((WARN_COUNT + 1))
  printf '[WARN] %s\n' "$1"
  if [ -n "${2:-}" ]; then printf '       %s\n' "$2"; fi
}

# Run a command with a hard timeout so nothing can hang the preflight.
# Portable across macOS and Linux (GNU `timeout` is not on stock macOS;
# perl is on both). If perl is somehow missing, run unguarded.
with_timeout() {
  _secs="$1"; shift
  if command -v perl >/dev/null 2>&1; then
    perl -e 'alarm shift; exec @ARGV; exit 127' "$_secs" "$@"
  else
    "$@"
  fi
}

# version_gte A B -> exit 0 if version A >= version B.
# Numeric segment-wise compare ("2.1.201" vs "1.0.34"), not a string compare.
version_gte() {
  IFS='.' read -r -a _va <<<"$1"
  IFS='.' read -r -a _vb <<<"$2"
  for _i in 0 1 2; do
    _sa="${_va[_i]:-0}"; _sb="${_vb[_i]:-0}"
    _sa="${_sa//[^0-9]/}"; _sb="${_sb//[^0-9]/}"
    _sa="${_sa:-0}"; _sb="${_sb:-0}"
    if [ "$_sa" -gt "$_sb" ]; then return 0; fi
    if [ "$_sa" -lt "$_sb" ]; then return 1; fi
  done
  return 0
}

echo "Loop Engineering — preflight"
echo

# ---------------------------------------------------------------------------
# Check 1: agent CLI (claude >= 1.0.34, or codex)
# ---------------------------------------------------------------------------
MIN_CLAUDE="1.0.34"
HAVE_CLAUDE=0

if command -v claude >/dev/null 2>&1; then
  ver_raw="$(with_timeout 10 claude --version </dev/null 2>/dev/null || true)"
  # Output looks like: "2.1.201 (Claude Code)" — take the first token.
  ver="$(printf '%s\n' "$ver_raw" | awk 'NR==1 {print $1}')"
  if [ -z "$ver" ]; then
    bad "claude CLI found but 'claude --version' returned nothing" \
        "reinstall: npm install -g @anthropic-ai/claude-code"
  elif version_gte "$ver" "$MIN_CLAUDE"; then
    ok "claude CLI $ver (>= $MIN_CLAUDE — /loop and /goal available)"
    HAVE_CLAUDE=1
  else
    bad "claude CLI $ver is older than $MIN_CLAUDE — /goal needs $MIN_CLAUDE+" \
        "run: claude update   (or: npm install -g @anthropic-ai/claude-code)"
  fi
elif command -v codex >/dev/null 2>&1; then
  ok "codex CLI found — no claude, and that's fine (see patterns/05-codex-goal.md)"
else
  bad "no agent CLI found (looked for claude and codex)" \
      "install: npm install -g @anthropic-ai/claude-code"
fi

# ---------------------------------------------------------------------------
# Check 2: credentials (API key env var, or a logged-in session)
# ---------------------------------------------------------------------------
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  ok "ANTHROPIC_API_KEY is set"
elif [ -n "${OPENAI_API_KEY:-}" ]; then
  ok "OPENAI_API_KEY is set"
elif [ -f "$HOME/.claude.json" ] && grep -q '"oauthAccount"' "$HOME/.claude.json" 2>/dev/null; then
  ok "logged-in Claude session detected (subscription login counts)"
elif [ -f "$HOME/.codex/auth.json" ]; then
  ok "logged-in Codex session detected"
else
  bad "no API key set and no logged-in session detected" \
      "export ANTHROPIC_API_KEY=... (or OPENAI_API_KEY=...). Subscription login also counts: run claude, type /login, then rerun this script."
fi

# ---------------------------------------------------------------------------
# Check 3: git identity
# ---------------------------------------------------------------------------
git_name="$(git config --get user.name 2>/dev/null || true)"
git_email="$(git config --get user.email 2>/dev/null || true)"
if [ -n "$git_name" ] && [ -n "$git_email" ]; then
  ok "git identity: $git_name <$git_email>"
else
  bad "git user.name and user.email are not both set" \
      "git config --global user.name \"Your Name\" && git config --global user.email you@example.com"
fi

# ---------------------------------------------------------------------------
# Check 4: ralph-loop plugin — the Ralph Wiggum loop, published in the
# official marketplace as "ralph-loop" (claude only; a failed install is a
# warning, not a failure — you can run every loop pattern tonight without it)
# ---------------------------------------------------------------------------
if [ "$HAVE_CLAUDE" -eq 1 ]; then
  plugins="$(with_timeout 15 claude plugin list </dev/null 2>/dev/null || true)"
  if printf '%s\n' "$plugins" | grep -qiE 'ralph-(loop|wiggum)'; then
    ok "ralph-loop plugin installed (the Ralph Wiggum loop)"
  else
    printf '  ...  ralph-loop plugin missing — attempting install (up to 30s)\n'
    if with_timeout 30 claude plugin install ralph-loop </dev/null >/dev/null 2>&1; then
      ok "ralph-loop plugin installed (the Ralph Wiggum loop)"
    else
      warn "ralph-loop plugin not installed (marketplace unreachable or install failed)" \
           "install manually later: claude plugin install ralph-loop"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "$PASS_COUNT/$TOTAL_COUNT checks passed"

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "Fix the FAIL lines above, then rerun: bash preflight.sh"
  exit 1
fi

if [ "$WARN_COUNT" -gt 0 ]; then
  echo "Warnings don't block you. Open README.md and pick your path."
else
  echo "All clear. Open README.md and pick your path."
fi
exit 0
