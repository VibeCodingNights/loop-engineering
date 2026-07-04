# Task Hypergraph

One loop drives one task toward one verifier. This skill is for when your goal doesn't fit in one task. It decomposes a large objective into a DAG of task units — each with its own verifier gate — and drives them in parallel map→do→review waves of agents. The graph lives on disk as a single self-rendering HTML file: open it in a browser and you're looking at the topology. The scripts that validate it and compute the next wave are deterministic Python. The agents do the work; the graph decides who runs next.

This is the most complex path in the repo. Everything here assumes you're comfortable with Claude Code's agent orchestration and Workflow fan-outs. If you want parallel agents without the graph machinery, start with [`../patterns/06-parallel-agents.md`](../patterns/06-parallel-agents.md) — worktrees plus concurrent loops, no topology file.

## When to use this vs. `/loop` or `/goal`

Use `/loop` or `/goal` when you have one task and one verifier. That covers most of tonight.

Use the hypergraph when the goal decomposes. Rule of thumb: more than 5 interdependent tasks, or you want multiple agents writing to the same repo in parallel with worktree isolation. "Migrate 40 route handlers where the middleware must land first" is a hypergraph. "Migrate one handler" is a `/goal`.

The tradeoff is real: you spend the first hour building the graph instead of running a loop. You get it back when wave two runs twelve agents at once.

## Quickstart

Every command below is real — flags verified against the scripts in this directory.

```bash
# 1. Scaffold a workspace. The LAST stdout line is the resolved root.
ROOT="$(bash scripts/scaffold.sh --project my-project | tail -n1)"
# smoke test (default mode is tmpdir; root lands in ${TMPDIR:-/tmp}/<project>_hypergraph):
bash scripts/scaffold.sh --project test --mode tmpdir
```

Scaffolding copies `validate.py`, `frontier.py`, `char_guard.py`, and `codex_exec.sh` next to the graph, so from here on you call them from `$ROOT`.

```bash
# 2. Write $ROOT/GOAL.md — the drive prompt. Hard budget: 4000 chars.
python3 "$ROOT/char_guard.py" "$ROOT/GOAL.md"        # OK -> proceed; OVER -> compress, re-run

# 3. Build the topology. Each task unit is an <article class="node"> in
#    $ROOT/topology.html (id, data-deps, data-status, data-verify) plus a prose
#    spec in $ROOT/nodes/<id>.md. Open topology.html in a browser to see the DAG.
open "$ROOT/topology.html"        # Linux: xdg-open

# 4. Validate: Kahn acyclicity + dangling-ref check. Prints OK, build_order, waves.
python3 "$ROOT/validate.py" "$ROOT/topology.html"

# 5. Compute the frontier: which nodes are ready to run in parallel right now.
python3 "$ROOT/frontier.py" "$ROOT/topology.html"
# prints: ready / clusters / isolate / blocked / done: N/M
python3 "$ROOT/frontier.py" "$ROOT/topology.html" --shard 12   # pre-chunk for fan-out
```

Launch one Workflow per shard, generated from `assets/workflow.template.js`. Agents run the nodes; you write `data-status` back into `topology.html`; recompute the frontier; repeat until `ready` is empty. `SKILL.md` is the full operating procedure — read it before your first real run.

Two optional pieces:

```bash
# Overnight autonomy: a Stop hook that blocks session exit while the frontier
# has ready work. Prints the settings snippet; --apply edits settings.json
# (with a .bak backup).
bash scripts/install_stop_hook.sh --root "$ROOT"
bash scripts/install_stop_hook.sh --root "$ROOT" --apply

# Codex as executor: the DO stage delegates to the Codex CLI through this
# adapter. Exits non-zero on any codex error, so the gate fails honestly.
bash scripts/codex_exec.sh --model gpt-5.5 -- "your prompt"
```

## Install as a skill

Copy this directory to `~/.claude/skills/task-hypergraph/` and Claude Code picks it up — `SKILL.md` is the entry point. Or skip the install: the scripts are standalone and run as shown above.

```bash
# from the repo root:
mkdir -p ~/.claude/skills
cp -R hypergraph ~/.claude/skills/task-hypergraph
```

## What's here

```
SKILL.md                        The skill itself. The full operating procedure. Vendored — do not edit.
scripts/
  scaffold.sh                   Writes the workspace: topology.html, GOAL.md, nodes/, maps/; copies helpers beside the graph.
  char_guard.py                 Hard character gate on GOAL.md (default 4000). OK/exit 0 or OVER/exit 1. No model judgment.
  validate.py                   Kahn acyclicity + dangling-ref check on topology.html; emits build_order and waves.
  frontier.py                   Ready-set, parallel clusters, worktree-isolate flags, --shard chunking for fan-out.
  install_stop_hook.sh          Generates a Stop hook that keeps the session running until the frontier empties.
  codex_exec.sh                 Codex CLI executor adapter; parses codex JSONL, fails loudly on codex errors.
assets/
  topology.template.html        The self-rendering graph. Machine-readable data-* attributes plus its own browser view.
  GOAL.template.md              The sub-4k drive-prompt template.
  node.template.md              Per-task-unit spec: objective, inputs, agent prompt, acceptance, verify, evidence.
  workflow.template.js          The parameterized map/do/review Workflow engine — the actual runtime.
references/
  gate-menu.md                  Gate types: golden-diff, intentional-diff+flag, test-green, forgeability.
  review-personas.md            Review stances: skeptic, brutalist, security, layered.
```

One vendored quirk: `references/review-personas.md` tells reviewers to emit verdicts per `../assets/verdict.schema.json`, which doesn't ship. The canonical verdict schema is the inline `VERDICT_SCHEMA` in `assets/workflow.template.js` — use that. The skill is vendored verbatim, so the dangling reference stays.

## The verifiers are still the game

Nothing about the graph changes the event's core rule. Every node carries a `data-verify` command that exits 0 or non-zero, runs fast, and needs no human judgment. A hypergraph with weak gates is just a faster way to generate plausible-looking code at scale. Pick each node's gate from [`references/gate-menu.md`](references/gate-menu.md) before you write the node.

Done looks like: `frontier.py` prints an empty `ready` line, every node is `done`, and one final integrated review passes over the whole change set. Then you land the commits — the graph never does.
