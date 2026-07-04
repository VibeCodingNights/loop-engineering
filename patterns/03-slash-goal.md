# 03 — /goal

`/loop` repeats. `/goal` verifies. You set a condition Claude cannot stop without meeting — and the done-or-not-done call is made by a separate model, not the one doing the work.

## When to use

Any loop you expect to run longer than ~10 minutes, or leave unattended at all. A model grading its own work is consistently too lenient — with `/loop`, the worker decides when it's done; with `/goal`, that judgment moves outside the worker.
Requires Claude Code ≥ 1.0.34 — `preflight.sh` already checked this.

## The pattern

```
/goal Migrate all API handlers in src/routes/ from Express to Hono. Exit when: `npm run typecheck` passes AND `npm test` passes AND no Express imports remain in src/.
```

Anatomy: one task, then an explicit exit condition where every clause is mechanically checkable — two commands with exit codes and a grep count. No clause needs taste.

Manage it:

```
/goal          # show the active condition, turns elapsed, last verdict reason
/goal clear    # abandon early — on success it clears itself
```

## How it works

`/goal` installs a session-scoped Stop hook. Every time the working agent tries to stop, a second evaluator agent wakes up — by default the model in `ANTHROPIC_SMALL_FAST_MODEL`, smaller and faster than the worker unless you've overridden it. It reads the recent transcript, can inspect your files, and returns exactly one structured verdict: `ok: true`, or `ok: false` with a reason. Not done: the stop is blocked, the reason is fed back, and the worker keeps going. Done: the goal clears itself.

Two consequences worth engineering around:

- **The evaluator sees a truncated transcript.** Long sessions get cut to fit its context window, and if the evidence might be in the cut portion, it must rule not done. Write conditions that force fresh evidence — "exit when `npm test` passes" makes the worker run the suite near the end, putting proof where the evaluator can see it.
- **The evaluator is strict, not psychic.** Give it "exit when the code is better" and it has nothing to check. Give it an exit code and it has everything.

## Run it

1. `cd` into your project, start `claude`. The workspace must be trusted and hooks enabled — `/goal` refuses otherwise.
2. Paste the `/goal` line. The condition becomes the directive; the agent starts working without asking what to do.
3. Stay for the first evaluation. If the verdict comes back not-done for a reason you didn't expect, your exit condition is ambiguous — tighten it now, not at midnight.
4. Walk away. `/goal clear` if you need out early.

## Failure modes

- **Unfalsifiable condition.** "Exit when the refactor is complete" gives the evaluator nothing mechanical. It will block stopping forever or guess. Every clause must be a command, a count, or a file state.
- **Condition tests process, not outcome.** "Exit when you have updated all the handlers" passes when the worker claims it did the steps. "Exit when no Express imports remain in src/" passes when the code says so.
- **A goal that can never pass keeps the agent working** — that's the contract. Set a provider spending cap and know your kill switches before leaving: [../safety/cost-caps.md](../safety/cost-caps.md), [../safety/kill-switches.md](../safety/kill-switches.md).
- **Stale evidence.** The suite passed an hour and forty edits ago. If the condition doesn't demand a fresh run, the evaluator may rule on old news — or refuse to rule at all.
- **Session-scoped means session-scoped.** The goal dies with the session. For loops that survive your laptop closing, see [04-background-agent.md](04-background-agent.md).

## Verifier hookup

The exit condition is your verifier inlined. Draft it as a script first — copy from [../verifiers/templates/](../verifiers/templates/) — then write the goal as "Exit when: `bash verifier.sh` exits 0."
Whether your goal is checkable at all is the real question: [../verifiers/good-vs-bad.md](../verifiers/good-vs-bad.md) settles it in one decision tree.
