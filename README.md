# Loop Engineering

Write loops, not prompts.

Boris Cherny built Claude Code. He doesn't prompt it anymore: "My job is to write loops." Peter Steinberger built OpenClaw: "You should be designing loops that prompt your agents." Geoffrey Huntley left one loop running for three months on a single prompt and got a compiled programming language with an LLVM backend. $297 in API costs against an estimated $50,000 of developer time. In the language, `slay` means `func` and `yeet` means `import`.

The loop is easy. The verifier is the whole game. Tonight you write both, on your own project, and leave with it still running. We check what shipped at breakfast.

[vibecodingnights.com](https://vibecodingnights.com)

## Get set up

1. Connect to the Wi-Fi — credentials are posted at the venue.
2. `git clone https://github.com/vibecodingnights/loop-engineering.git`
3. `cd loop-engineering && bash preflight.sh`
4. Pick your path: [Beginner](#start-here-beginner) or [Advanced](#start-here-advanced).

`preflight.sh` checks your Claude Code version (≥ 1.0.34 for `/goal` — current stable is 2.1.x, so this only catches ancient installs), your API key, your git config, and installs the Ralph Wiggum plugin if it's missing. No project of your own tonight? Open [no-project.md](no-project.md).

## Start Here: Beginner

Goal: leave tonight with one loop running on your own project.

**1. Pick your task** (10 min). Open your project. Find one thing with a mechanically checkable outcome. Good: "all tests pass," "type checker clean," "these 12 endpoints return 200." Bad: "improve the code," "make it faster" — the loop never knows when to stop. Stuck? [verifiers/good-vs-bad.md](verifiers/good-vs-bad.md) has a decision tree.

**2. Pick your loop pattern** (5 min). Read one file in [patterns/](patterns/):

- [patterns/01-ralph-loop.sh](patterns/01-ralph-loop.sh) — the original `while true` bash hack. Three lines. Start here to see the guts.
- [patterns/02-slash-loop.md](patterns/02-slash-loop.md) — Claude Code's built-in `/loop`. The easiest entry.
- [patterns/03-slash-goal.md](patterns/03-slash-goal.md) — `/goal` adds a separate verifier model that checks each iteration. Use it for anything longer than 10 minutes.

**3. Write your verifier** (15 min — this is the hard part). Copy the closest match from [verifiers/templates/](verifiers/templates/) and edit it. Your verifier must:

- be a command that exits 0 (pass) or non-zero (fail)
- run in under 30 seconds
- require no human judgment
- test the actual outcome, not the process

Example — migrating a codebase from JavaScript to TypeScript:

```bash
#!/usr/bin/env bash
# verifier: no .js files remain in src/, and tsc compiles clean
set -euo pipefail
JS_COUNT=$(find src/ -name "*.js" | wc -l | tr -d ' ')
[ "$JS_COUNT" -eq 0 ] || exit 1
npx tsc --noEmit
```

**4. Set your cost cap** (2 min). Read [safety/cost-caps.md](safety/cost-caps.md) and set a spending limit in your API dashboard. $5 is plenty for the evening. $10–20 if you run overnight.

**5. Start the loop** (1 min). Fire it off. Watch the first iteration to make sure it isn't immediately broken. Then work on something else, help a neighbor, or get dinner.

**6. Fill out your loop journal** (5 min before you leave). Copy [journal/TEMPLATE.md](journal/TEMPLATE.md) to `journal/entries/your-name.md`: what you're looping on, what your verifier checks, when you started, your cost cap, your repo URL. Post it in the shared channel. That's what we check at breakfast.

## Start Here: Advanced

Already run `/loop` or `/goal`? Pick a track. Combine them if you want.

| Track | What you build | Start |
|---|---|---|
| **A. Verifier engineering** | Composite, semantic, and cost-aware verifiers — checks good enough to trust unsupervised output. The templates are the floor, not the ceiling. | [verifiers/](verifiers/) |
| **B. Task hypergraph** | Decompose a large goal into a parallel DAG of agent tasks, each with its own verifier, driven as concurrent waves. The most complex path. | [hypergraph/](hypergraph/) |
| **C. Background agents + overnight** | A loop that survives your laptop closing. Server-side sessions, draft PRs, context-exhaustion recovery. Close the lid at 10, check the PR at breakfast. | [patterns/04-background-agent.md](patterns/04-background-agent.md) |
| **D. Parallel loops** | Multiple concurrent loops in git worktrees, plus a coordinator that merges and re-verifies the integrated result. | [patterns/06-parallel-agents.md](patterns/06-parallel-agents.md) |

On Codex instead of Claude Code? [patterns/05-codex-goal.md](patterns/05-codex-goal.md).

## Repo tour

| Path | What it is |
|---|---|
| [README.md](README.md) | You are here. |
| [preflight.sh](preflight.sh) | Run once on arrival. Checks your setup, prints pass/fail. |
| [no-project.md](no-project.md) | 10 open-source repos with loop-ready issues, each with a suggested verifier. |
| [patterns/](patterns/) | Six loop patterns, from a three-line bash loop to parallel background agents. Read one, copy it, go. |
| [verifiers/](verifiers/) | The real curriculum. Thesis, decision tree, copy-paste templates, anti-patterns, and a cost/time watchdog. |
| [hypergraph/](hypergraph/) | The full task-hypergraph skill. Advanced path, self-directed. |
| [safety/](safety/) | Cost caps, kill switches, context rot. Read before running overnight. |
| [journal/](journal/) | Loop journals — the overnight accountability layer. Fill one out before you leave. |
| [host/](host/) | Organizer-only. Not for attendees. |

## What "done" looks like at 10 PM

| Level | You leave with |
|---|---|
| **Minimum viable** | You understand the difference between a good and bad loop goal. You ran `/loop` or `/goal` at least once on your own project. You saw it iterate. |
| **Beginner target** | A loop running with a mechanical verifier (a script that exits 0/1). A cost cap set. A loop journal filled out. You understand why the verifier is harder than the loop. |
| **Advanced target** | A non-trivial verifier — composite, semantic, or cost-aware. Maybe parallel loops or a hypergraph-orchestrated build running. Designed for overnight autonomy, with the design rationale in your journal. |
| **Night-one target** | A loop still running when you walk out. Your journal posted to the channel. You check what shipped at breakfast. |

## Breakfast

Post your journal to the shared channel before you leave. In the morning, post what your loop produced, how many iterations it ran, what it cost, and whether your verifier held up. The verifiers that failed overnight are the most interesting data points.

We check what shipped at breakfast.
