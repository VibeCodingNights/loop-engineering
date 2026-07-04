# 04 — Background Agents

Close the laptop at 10. Check the draft PR at breakfast. This pattern is how.

## When to use

Your task won't finish tonight — a migration, a big refactor, a test suite that needs hours of grinding. You want the loop to keep running after you leave, and you want the result waiting as a branch or PR in the morning.

## The pattern

Three ways to survive the laptop closing, in order of how well they survive it.

### Option A: Cloud session (`claude --cloud`)

The session runs on Anthropic-managed infrastructure, not your machine. Close the browser, close the laptop, lose Wi-Fi — it keeps going. Requires claude.ai subscription auth (Pro/Max/Team; research preview as of this writing). Preview-gated means `--cloud` and `--teleport` don't show up in `claude --help` — your install isn't broken, run them anyway. The cloud clones your repo **from GitHub**, not from your disk — push first.

```bash
git push    # cloud clones from GitHub, not your laptop

claude --cloud "Migrate src/routes/ from Express to Hono.
Done when: bash verify.sh exits 0.
Run bash verify.sh after every change. Do not weaken the verifier.
When it exits 0, push the branch and open a draft PR."
```

Commit `verify.sh` to the repo before you start — the cloud container can only run what's in the clone. You can also start the same session from a browser at [claude.ai/code](https://claude.ai/code): pick the repo, paste the same goal.

### Option B: Local background agent (`claude --bg`)

```bash
claude --bg "Fix every failing test in src/. Done when: npm test exits 0."
claude agents    # watch all background sessions from one screen
```

Returns immediately; the session runs on **your machine**. Good for "run while I get food." Not an overnight pattern — it sleeps when the laptop does.

### Option C: The humble fallback — tmux on a machine that stays awake

Always works, any provider, no research preview. A Ralph loop (see [01-ralph-loop.sh](01-ralph-loop.sh)) inside tmux, pushing every iteration so the work survives even if the machine doesn't.

```bash
tmux new -s loop
# inside tmux:
while :; do
  claude -p "$(cat PROMPT.md)" --allowedTools "Bash,Edit,Write,Read" --max-budget-usd 2
  git add -A && git commit -m "loop: $(date '+%H:%M')" && git push
  bash verify.sh && break
done
# detach: Ctrl-b d
```

Note the cap is **per iteration** — `--max-budget-usd` only bounds one `claude -p` call, so 2 dollars times N iterations is your real ceiling. Set the total in your API dashboard too ([../safety/cost-caps.md](../safety/cost-caps.md)).

macOS sleeps when the lid closes. Either run `caffeinate -i tmux new -s loop` on a plugged-in machine, or use a desktop, a server, or a $5 VM. `nohup` works the same way if you hate tmux.

## Run it

The 10 PM checklist:

1. **Prove the verifier fails.** `bash verify.sh; echo $?` — non-zero, for the right reason. A verifier that already passes means your loop exits at 10:01 and ships nothing.
2. **Start the session** (Option A for true overnight). Tell it explicitly: run the verifier, push the branch, open a draft PR when green.
3. **Watch the first iteration.** Two minutes. Catch the immediately-broken loop now, not at breakfast.
4. **Fill out your loop journal** ([../journal/TEMPLATE.md](../journal/TEMPLATE.md)), post it to the channel.
5. Close the laptop.

At breakfast:

```bash
claude --teleport          # pull the cloud session + its branch into your terminal
claude --from-pr 42        # or reopen the session linked to PR #42
```

Or just open the draft PR. Cloud sessions push branches through Anthropic's GitHub proxy; if the agent didn't open the PR itself, one click in the web diff view does it. Review the diff against your verifier, not line by line — trusting the PR without reading every line is the whole point of writing a real verifier.

## Failure modes

- **Context rot.** One session grinding for 8 hours degrades — it forgets, repeats, undoes its own work. Fresh-context iterations (Option C's loop) beat one long session for long tasks. Read [../safety/context-rot.md](../safety/context-rot.md).
- **Runaway cost.** Overnight means nobody is watching the meter. Set the provider dashboard cap before you leave — $10–20 for an overnight run — and wrap local loops in [../verifiers/watchdog.sh](../verifiers/watchdog.sh). Read [../safety/cost-caps.md](../safety/cost-caps.md).
- **Review-burden cliff.** Generating PRs overnight is easy; verifying them is not. One loop, one PR, one verifier. Five overnight loops means five unreviewed PRs at breakfast, which means zero merged PRs at lunch.
- **The session stops early.** Agents sometimes declare victory and stop with work remaining. A Stop hook can block the stop while a verifier says there's still work — [../hypergraph/scripts/install_stop_hook.sh](../hypergraph/scripts/install_stop_hook.sh) installs one wired to a task hypergraph, and the trick generalizes: any Stop hook that checks your verifier and emits `{"decision":"block"}` keeps the session going.
- **The verifier was already green.** See step 1. This is the most common way to wake up to nothing.

## Verifier hookup

Your exit condition is a script from [../verifiers/templates/](../verifiers/templates/) — committed to the repo so the cloud session can run it. For local overnight runs, wrap the whole loop in [../verifiers/watchdog.sh](../verifiers/watchdog.sh): it kills on spend, wall-clock, or stalled file changes.
