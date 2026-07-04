# Context Rot

Long sessions degrade. Not loudly — the model doesn't announce it's confused. Output stays fluent while the session quietly loses the plot. If you're leaving something running overnight, this is the failure you're designing against.

## What it looks like

- **Forgotten constraints.** Hour one: "don't touch the database schema." Hour four: it touches the schema. The instruction is still in the transcript somewhere; it's no longer in effect.
- **Redone work.** It re-implements a function it finished two hours ago, or re-runs a migration that already succeeded.
- **Goal drift.** The task was "migrate the routes." It's now refactoring the logger. Each step looked locally reasonable.
- **Thrashing.** The same error, the same fix, iteration after iteration. It's lost the memory of having already tried this.

## Why loops resist it better than one long chat

A chat's only memory is its context window, and the window is finite — old turns get compacted or dropped. A loop's memory doesn't have to live there at all. **It lives in files and git.** The repo is the state; the context window is just a working buffer. Each iteration can throw the buffer away, re-read the state from disk, and pick up exactly where the last one left off.

That's the deep reason the Ralph loop works: rot can't accumulate across iterations that don't share a context window.

## Workarounds that work

**1. Keep state on disk.** A `PLAN.md` or `PROGRESS.md` the loop re-reads at the start of every iteration. The prompt is: "Read PLAN.md. Do the next unchecked item. Check it off. Commit." Done-ness lives in the checklist and in git history, not in the model's memory.

**2. Fresh context per iteration.** `claude -p` in the Ralph loop ([../patterns/01-ralph-loop.sh](../patterns/01-ralph-loop.sh)) starts a brand-new context every pass. That is not a limitation — it's the feature. Every iteration wakes up with a clean head and reads the repo to find out where things stand.

**3. `/goal`'s cadence.** In a plain long session, drift compounds silently. `/goal` re-asserts the goal each cycle and puts a separate verifier model at every iteration boundary — one binary call, done or not done — made by a model that isn't the one drifting. Compaction still happens in long sessions, but the goal and its exit condition are re-checked instead of quietly fading. See [../patterns/03-slash-goal.md](../patterns/03-slash-goal.md).

**4. The Stop hook.** For overnight autonomy: [../hypergraph/scripts/install_stop_hook.sh](../hypergraph/scripts/install_stop_hook.sh) installs a hook that catches a session ending with the goal incomplete — context exhausted — and recovers by relaunching against the on-disk state instead of just dying.

**5. Smaller goals.** A goal that finishes in twenty iterations doesn't live long enough to rot. If your task needs hundreds, decompose it: a DAG of small tasks, each with its own verifier, is many short-lived contexts instead of one long dying one. [../hypergraph/](../hypergraph/README.md) is the full treatment.

## What's not solved

Honesty section. Do not skip.

- **Rot inside a single iteration.** Fresh-context-per-pass resets between iterations. If one pass runs for two hours, rot happens inside it, and nothing above helps.
- **Compaction is lossy and silent.** When a long session compacts, you don't get a list of what was forgotten. You find out when a dropped constraint gets violated.
- **On-disk state is advisory.** The model can read `PLAN.md` and still ignore it. State on disk makes recovery possible; it doesn't make compliance guaranteed.
- **Drift has no mechanical detector.** The [watchdog](../verifiers/watchdog.sh) catches *no progress*. It cannot catch *confident progress in the wrong direction*. The only thing standing between a drifted loop and a merged PR is your verifier — which is the whole game. See [../verifiers/README.md](../verifiers/README.md).
