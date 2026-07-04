# 05 — Codex: The Goal Loop Without /goal

Codex CLI has no `/goal` and no separate verifier model. You get the same machine in fifteen lines of bash: `codex exec` does the work, your verifier makes the done/not-done call.

## When to use

You're on OpenAI, not Anthropic. Everything else tonight still applies — the loop is easy, the verifier is the game. This file gives you the loop; `../verifiers/` gives you the game.

## The pattern

Install and authenticate:

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh    # or: npm install -g @openai/codex
codex login                                             # sign in with a ChatGPT plan
# or with an API key:
printenv OPENAI_API_KEY | codex login --with-api-key
codex login status
```

The verifier-gated loop. Save as `codex-goal.sh` in your project:

```bash
#!/usr/bin/env bash
# codex-goal.sh — /goal, reimplemented in bash. Your verifier is the judge.
set -u
PROMPT="Make every test in this repo pass. Run 'npm test' yourself, fix real causes. Do not weaken or delete tests."
VERIFY="bash verify.sh"     # exits 0 = done. Copy from ../verifiers/templates/, edit.
MAX_ITER=25

for i in $(seq 1 "$MAX_ITER"); do
  if OUT=$($VERIFY 2>&1); then
    echo "verifier green after $((i-1)) iterations"; exit 0
  fi
  if [ "$i" -eq 1 ]; then
    codex exec -s workspace-write "$PROMPT"
  else
    codex exec resume --last -c 'sandbox_mode="workspace-write"' \
      "The verifier still fails. Last 20 lines of its output:
$(printf '%s\n' "$OUT" | tail -20)
Fix the cause, then stop."
  fi
done
$VERIFY && { echo "verifier green at the wire"; exit 0; }
echo "MAX_ITER=$MAX_ITER reached, verifier still red" >&2
exit 1
```

One flag trap, verified against codex 0.142: `codex exec` takes `-s workspace-write`, but `codex exec resume` **rejects** `-s` — sandbox mode goes through `-c 'sandbox_mode="workspace-write"'` on resume. The script above handles both. `../hypergraph/scripts/codex_exec.sh` is the hypergraph's adapter for `executor=codex` and exists so this divergence is fixed in exactly one place — read it if you want thread IDs, token counts, and clean error handling.

Two variants worth knowing:

- **Fresh context per iteration** (the Ralph pattern): replace the `resume --last` branch with a plain `codex exec "$PROMPT ..."`. Costs more tokens, beats context rot on long runs.
- **Machine-readable output**: add `--json` for a JSONL event stream, or `-o last-message.txt` to capture the final agent message.

## Run it

```bash
bash verify.sh; echo $?      # must be non-zero NOW, for the right reason
chmod +x codex-goal.sh
tmux new -s codex 'bash codex-goal.sh'   # detach: Ctrl-b d
```

Watch the first iteration complete before you walk away. For overnight, run it on a machine that stays awake — see `04-background-agent.md`, Option C; everything there applies here unchanged. `codex cloud exec` can submit server-side tasks, but it's marked experimental in the CLI — verify it works on your account before trusting it with the night.

## Parity gaps

Honest accounting, one line each:

- No `/goal`: there is no separate verifier model making the done call — your script is the only judge, which is why it must be mechanical.
- No Stop hook: nothing stops Codex from ending a turn early with work remaining — the outer bash loop is your persistence layer.
- No budget flag: `codex exec` has no `--max-budget-usd` equivalent — set the spend cap in the OpenAI platform dashboard (`../safety/cost-caps.md`) and wrap the loop in `../verifiers/watchdog.sh`.
- Cloud/background execution (`codex cloud`) is experimental; tmux plus `codex exec` is the reliable overnight path today.

## Failure modes

- **The model grades its own work.** The prompt tells Codex to run tests; fine. But the loop's exit is `$VERIFY` running *outside* the session. Never let the agent's "all tests pass now" be the gate.
- **`resume --last` grabs the wrong session.** Run two loops from the same directory and each `--last` resumes whichever finished most recently. One loop per directory, or capture the thread ID (`codex_exec.sh` prints `thread_id:` for exactly this).
- **Sandbox blocks the writes.** Without `-s workspace-write` (or the `-c sandbox_mode` form on resume), Codex may be unable to edit files — the loop burns iterations producing nothing.
- **25 iterations of a broken verifier.** If `verify.sh` can never exit 0 — wrong path, missing dependency — you pay for MAX_ITER attempts at an impossible goal. Run the verifier by hand first.

## Verifier hookup

Verifiers are provider-neutral bash: every template in `../verifiers/templates/` drops into `VERIFY=` above unchanged. Wrap the whole loop in `../verifiers/watchdog.sh` for spend, runtime, and stall kills — it doesn't care which CLI is inside.
