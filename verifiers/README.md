# The Verifier Is the Whole Game

The loop is easy. It's three lines of bash — read `../patterns/01-ralph-loop.sh`, you'll understand all of it. The verifier is the craft. It is the only thing standing between you and a night of expensive, plausible-looking garbage.

Three facts, in increasing order of discomfort:

1. **A model grading its own work is consistently too lenient.** This is why `/goal` exists: Anthropic built a separate, smaller model that reads the session after each iteration and makes one binary call — done or not done. They didn't do that for fun. They did it because self-grading fails.

2. **Most people running loops right now skip verification entirely.** They generate enormous volumes of plausible code that silently drifts from intent. The loop keeps going. Nothing checks it. The diff at breakfast is large and wrong.

3. **The overnight loop that ships a draft PR by morning is not hard to build anymore.** Writing a verifier good enough that you trust the PR without reading every line — that's the craft. That's what tonight is about.

"Make the tests pass" is a good loop goal because success is mechanically checkable. "Improve the code" is a bad one because the loop never knows when to stop. Everything in this directory is an elaboration of that one sentence.

## The Four Rules

Your verifier must:

1. **Be a command that exits 0 (pass) or non-zero (fail).** One binary answer. Not a report, not a score, not a vibe. If your exit condition can't be expressed as an exit code, you don't have one yet.
2. **Run in under 30 seconds.** The loop runs it every iteration. A 20-minute verifier means three checks an hour — your loop spends the night waiting, not working.
3. **Require no human judgment.** You are asleep. If the check needs you to look at something, it is not a verifier, it is a to-do item.
4. **Test the actual outcome, not the process.** "The tests pass" is an outcome. "The agent ran the tests" is a process. Only outcomes count.

That's the whole discipline. Here it is, complete, for a JS-to-TS migration:

```bash
#!/usr/bin/env bash
# verifier: no .js files remain in src/, and tsc compiles clean
set -euo pipefail
JS_COUNT=$(find src/ -name "*.js" | wc -l | tr -d ' ')
[ "$JS_COUNT" -eq 0 ] || exit 1
npx tsc --noEmit
```

Exit code, fast, no judgment, outcome. Four for four.

## What's in This Directory

| File | What it is |
|---|---|
| [`good-vs-bad.md`](good-vs-bad.md) | Decision tree: is your goal mechanically checkable? Fifteen goals, judged, with rewrites for the fixable ones. Start here. |
| [`anti-patterns.md`](anti-patterns.md) | The rogues' gallery: verifiers that always pass, cheatable verifiers, model-as-judge leniency, the runaway loop. Read before running overnight. |
| [`templates/`](templates/) | Copy one, edit it for your project. See below. |
| [`watchdog.sh`](watchdog.sh) | Wraps your loop. Kills it if spend exceeds $N, runtime exceeds T hours, or nothing has changed on disk in M minutes. Mandatory reading for overnight runs. |

## The Templates

Nine scripts in [`templates/`](templates/). Each one already obeys the four rules. Copy the closest match, edit the exit condition.

- **`test-pass.sh`** — exit 0 when the test suite passes. The baseline.
- **`type-check.sh`** — exit 0 when `tsc` / `mypy` / `pyright` comes back clean.
- **`build-clean.sh`** — exit 0 when the build succeeds with no warnings.
- **`coverage-threshold.sh`** — exit 0 when coverage is at or above `$THRESHOLD`%.
- **`no-pattern.sh`** — exit 0 when grep finds zero matches. The migration verifier: "no Express imports remain."
- **`api-conformance.py`** — exit 0 when every endpoint matches the OpenAPI spec.
- **`snapshot-diff.sh`** — exit 0 when output matches a golden snapshot.
- **`composite.sh`** — the AND-combinator. Runs N verifiers; all must pass. This is how you build serious verifiers out of simple ones.
- **`custom-eval.py`** — blank template with the structure and comments. For when your check doesn't fit the others.

## Tonight

1. Read [`good-vs-bad.md`](good-vs-bad.md). Run your goal through the tree.
2. Copy a template. Edit it until it fails on your repo as it stands and would pass on the repo you want.
3. Run it by hand once. If it passes before the loop has done anything, your verifier is broken, not your project finished.
4. Wire it into your loop. Running overnight? Wrap it in [`watchdog.sh`](watchdog.sh) and read [`../safety/`](../safety/) first.

The loop writes the code. The verifier decides if it counts. Spend your time where the leverage is.
