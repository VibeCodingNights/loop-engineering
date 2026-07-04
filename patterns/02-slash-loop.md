# 02 — /loop

The Ralph loop, built in. One command inside Claude Code re-runs a prompt on a schedule — or lets the model pace itself. No bash file, no second terminal.

## When to use

Your task fits in one sentence and its exit condition is a command the agent can run. You want the loop inside your live session, where you can watch it.
For anything you plan to leave unattended past ~10 minutes, use `/goal` instead — `/loop` repeats, it does not verify. See [03-slash-goal.md](03-slash-goal.md).

## The pattern

Interval form — a leading `Ns`/`Nm`/`Nh`/`Nd` token sets the cadence:

```
/loop 15m run bash verifier.sh — if it fails, fix the first failing check and commit; if it exits 0, say DONE and stop the loop
```

A trailing time phrase works too: `... every 20m`, `... every 5 minutes`.

Self-paced form — omit the interval and the model schedules its own next wakeup. It can also arm event monitors, so it wakes when CI finishes instead of on a clock:

```
/loop run bash verifier.sh, fix the first failure, commit, stop when it exits 0
```

The prompt can be another slash command: `/loop 5m /my-check`.

Two good loops:

```
/loop 15m run npx tsc --noEmit and fix the first type error; commit; stop the loop when it reports zero errors
```
Good because the compiler prints a number. Zero is zero. Nothing to argue about.

```
/loop 10m run npm test — fix the first failing test and commit; when the suite is green, stop the loop
```
Good because success is an exit code, not an opinion.

Two bad loops:

```
/loop 30m improve the code in src/
```
Bad because the loop never knows when to stop — there is always another "improvement," so it runs until your budget does.

```
/loop 1h make the error messages clearer
```
Bad because "clearer" is a judgment call, and the model judging its own prose either declares victory on iteration one or never.

## Run it

1. `cd` into your project and start `claude` (needs ≥ 1.0.34; verified against 2.1.201).
2. Paste the `/loop` line. It executes the prompt immediately, then repeats on schedule.
3. Watch the first iteration. If it goes sideways in minute one, it will go sideways all night.
4. To stop: interrupt (Esc) and say "stop the loop" — Claude cancels its own schedule. Scheduled loops also auto-expire after a few days, but do not use that as your kill switch.

## Failure modes

- **The worker grades itself.** The exit condition lives in your prompt, and the same model doing the work decides it is met. Self-grading is lenient. This is the exact problem `/goal` was built to fix.
- **Loop runs, nothing changes.** Each wakeup has no memory beyond the repo. If the prompt doesn't say "commit and leave notes," iteration 12 rediscovers iteration 3.
- **Interval shorter than the work.** Iteration N+1 fires while N is mid-edit. Give it room, or drop the interval and let it self-pace.
- **Nothing bounds cost.** `/loop` has no budget flag. Set a provider spending cap before you look away — see [../safety/cost-caps.md](../safety/cost-caps.md).
- **The loop lives in your session.** Close the laptop, the loop pauses. For overnight, see [04-background-agent.md](04-background-agent.md).

## Verifier hookup

Make the loop's exit a script, not a vibe: copy the closest match from [../verifiers/templates/](../verifiers/templates/) and phrase the loop as "run it, fix the first failure, stop when it exits 0."
Not sure your goal is checkable at all? [../verifiers/good-vs-bad.md](../verifiers/good-vs-bad.md) has the decision tree.
