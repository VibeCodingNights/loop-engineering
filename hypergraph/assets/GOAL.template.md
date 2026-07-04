# GOAL

## Objective
{{OBJECTIVE}}

## Root
{{ROOT}}

## Mandate
You own this objective end to end. You implement and you test; the operator
lands commits. Never push or merge — hand the operator a clean, tested branch.

### 1. Topology first
Before touching code, build the task hypergraph. Survey {{ROOT}}, then emit
nodes grounded in REAL code as `path:line`. Reuse before you add: each node
cites the existing symbol it extends or the absence it fills. Edges are hard
dependencies only. A node is *ready* when every dependency is `gate:pass`.

### 2. Drive in waves — maximize parallelism
Loop until exit. Each wave:
- Re-read this GOAL and the driver FIRST, then re-derive what is ready.
- map: enumerate every independent ready node and cluster.
- do: launch ALL of them at once as Workflow fan-outs — one worker per node.
  Never serialize work that can run in parallel.
- review: gate each returned result before the next wave.
You are the single spawner: you schedule and read, workers act and report.
Workers never spawn workers and never schedule.

### 3. Worktree isolation
Any node that mutates files a sibling in the same wave also touches runs in its
own git worktree. Nodes with disjoint file sets may share the tree. Integrate
through the operator's branch — never stomp a sibling's edits.

### 4. Gates are honest
A gate passes only on real, reproduced evidence. A truthful `gate:fail` is a
SUCCESS: report it plainly with the failing command and output. Never
fake-pass, never soften, never skip a gate to look finished.

## Tracks & gates
{{TRACKS_AND_GATES}}

## Invariants — hold on every wave
{{INVARIANTS}}

### 5. Final integrated review
When all tracks reach `gate:pass`, run ONE adversarial review of the whole
integrated system. It SUPERSEDES every per-stage checklist: re-derive
correctness against {{OBJECTIVE}} end to end, attack seams and assumptions.
Per-node green does not imply integrated green — prove the whole.

## Exit
{{EXIT_CONDITION}}

## Autonomy
{{AUTONOMY}}
