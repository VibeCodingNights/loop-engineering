# 06 — Parallel Agents: One Worktree Per Loop

Run three loops on the same repo at once without them trampling each other. Git worktrees give each loop its own checkout — separate directory, separate branch, shared history.

## When to use

Your project has several independent tasks and you have one evening. One loop per task, all running concurrently, merged by a coordinator at the end. If your tasks have dependencies on each other, compute the parallel-safe set first — that's what `frontier.py` is for, below.

## The pattern

One worktree and branch per task, created from the repo root:

```bash
git worktree add ../myproj-tests -b loop/tests
git worktree add ../myproj-types -b loop/types
git worktree add ../myproj-docs  -b loop/docs
git worktree list
```

Why this kills mid-flight conflicts: two agents in the **same** checkout race each other — agent A's `git add -A` commits agent B's half-finished edits, and both loops corrupt each other's verifier runs. Worktrees make each loop's writes invisible to the others until merge time, where conflicts are explicit, visible to git, and handled serially by one coordinator instead of silently at write time.

One loop per worktree, one tmux session each. Each worktree gets its own `PROMPT.md` and its own scoped `verify.sh`:

```bash
tmux new -d -s tests -c ../myproj-tests \
  'while :; do claude -p "$(cat PROMPT.md)" --allowedTools "Bash,Edit,Write,Read"; bash verify.sh && break; done'
tmux new -d -s types -c ../myproj-types \
  'while :; do claude -p "$(cat PROMPT.md)" --allowedTools "Bash,Edit,Write,Read"; bash verify.sh && break; done'
```

(Claude Code can also mint a worktree itself — `claude -w tests` — if you'd rather it manage the checkout.)

The coordinator: merge branches back **one at a time**, re-running the full-project verifier after each merge. Per-branch verifiers passing does not mean the integration passes — and merging one at a time tells you exactly which branch broke it.

```bash
#!/usr/bin/env bash
# coordinator.sh — run from the main checkout once task loops go green
set -euo pipefail
git checkout -b integrate
for b in loop/tests loop/types loop/docs; do
  git merge --no-ff "$b" -m "merge $b" \
    || { echo "conflict merging $b — resolve by hand, rerun"; exit 1; }
  bash verify-all.sh \
    || { echo "integrated verifier failed after $b"; exit 1; }
done
echo "all branches merged, integrated verifier green"
```

## Which tasks can actually run in parallel

Don't guess — compute it. `../hypergraph/scripts/frontier.py` reads a `topology.html` where each task node declares `data-deps` (task IDs that must finish first), `data-files` (files it touches), and `data-status`. It prints the ready frontier:

```bash
python3 ../hypergraph/scripts/frontier.py topology.html
# ready: t1 t3 t4           deps all done — launchable now
# clusters: t1 t3 | t4      groups sharing no files and no hyperedge
# isolate: t4               ready, but its files overlap another ready task
# blocked: t2(needs: t1)    waiting on unfinished dependencies
# done: 1/5
```

Read it like this: everything inside one cluster is safe to run concurrently; anything in `isolate` touches files another ready task also touches — that one **must** get its own worktree. `--shard N` chunks the ready set for fan-out; exit code 3 means deadlock (nothing ready, nothing running, not done — your dependency graph has a knot). Mark finished tasks `data-status="done"` in `topology.html`, rerun, launch the next wave. The full workflow lives in `../hypergraph/README.md`.

## Run it

1. Split your goal into tasks that touch **disjoint files**. Partition by file ownership, not by feature — "tests", "types", "docs" beats "login", "signup" when both features share `models/user.ts`.
2. Create the worktrees. Write a scoped `verify.sh` per task and prove each one fails before starting.
3. Launch one loop per worktree. Watch each loop's first iteration.
4. When loops go green, run `coordinator.sh`. Ship the `integrate` branch.
5. Clean up: `git worktree remove ../myproj-tests && git branch -d loop/tests` — a stale worktree pins its branch and blocks re-checkout later.

## Failure modes

- **Two agents edit shared files anyway.** Lockfiles, generated code, shared config — `package.json`, snapshots, schema files. Declare `data-files` honestly and let frontier.py's `isolate` catch the overlap, or expect merge pain.
- **Merge-order sensitivity.** A-then-B merges clean; B-then-A conflicts, or compiles into something subtly different. The coordinator's fixed order plus verify-after-each-merge makes the failure point visible instead of mysterious.
- **Green per branch, red integrated.** Each branch's verifier is scoped to its task; only the coordinator runs `verify-all.sh`. Skipping the integrated check is how three passing branches produce one broken main.
- **N loops, N times the spend, N things to review.** The review-burden cliff from `04-background-agent.md` compounds here. Three parallel loops is a productive evening; five is a backlog.

## Verifier hookup

Each worktree runs a scoped verifier copied from `../verifiers/templates/`; the coordinator runs the integrated one — build it as an AND of the scoped checks with `../verifiers/templates/composite.sh`.
