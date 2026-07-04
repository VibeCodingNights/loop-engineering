---
name: task-hypergraph
description: >-
  Crystallize a one-line objective into a sub-4k GOAL, scaffold a resumable
  task-hypergraph workspace on disk, and drive it to completion via PARALLEL
  map->do->review cycles run as Workflow fan-outs, with adversarial review
  gates, worktree isolation, and honest pass/fail gates. Use when decomposing a
  repo / refactor / audit / build into a parallel-orchestrated effort — when the
  user types the setup megaprompt or its idioms: "structure a/our task
  hypergraph", "draw out the topology and fill in the task units", "map->do->review
  cycles in workflows, maximizing parallelism", "let's wield workflows",
  "ultracode this with engineering distinction", "structure our /goal prompt
  under 4k", or "structure the next hypergraph as we did before, you know what to
  do". Front-door alias: /goal. NOT for one-off single-file edits, and NOT a
  standing/background self-firing goal-driver — it is invocation-triggered at the
  setup seam.
---

# task-hypergraph

Decompose work into a **task hypergraph** (nodes = task units, hyperedges = dependencies / planes), persist it to disk, and **drive it to completion with maximally-parallel `map -> do -> review` cycles**, each wave executed by a **Workflow** fan-out.

## What this is — and what it is NOT

This skill is a **hub that freezes the stable control core and EMITS the runtime.** It is *not itself* the loop.

- It **bundles**: a crystallization recipe + char-guard, a deterministic directory scaffold, a **self-rendering HTML topology** + prose task-unit template, an HTML topology validator + frontier computer, a **parameterized Workflow template** (the real map/do/review engine), and a Stop-hook installer.
- The **live fan-out runs inside a generated Workflow script** (`assets/workflow.template.js`) — the model's real multi-agent runtime. Autonomy across context-exhaustion runs inside an installed **Stop hook**.
- **SKILL.md prose never re-implements the fan-out.** A skill is loaded into the orchestrator's context and executed by the model; it has no runtime, no memory, and cannot enforce parallel control flow, worktree isolation, wave barriers, or survival across compaction. Encoding the loop as prose for the model to step through would regress below the workflow-script runtime and re-introduce re-pasting friction. **You (the orchestrator) drive; each wave is a Workflow; the Workflow's agents touch the files.**

## Operating procedure — a meta `map -> do -> review`

> Paths below are relative to this skill directory. `<root>` is the workspace `scaffold.sh` prints (default `${TMPDIR:-/tmp}/<project>_hypergraph`). After scaffolding, the helper scripts are **copied next to the graph**, so call them as `<root>/validate.py` etc. **`<root>/topology.html` is both the authoritative graph and its own rendered view — open it in a browser to *see* the hypergraph.**

### Phase A — CRYSTALLIZE (map; read-only)
1. Take the one-line **objective** + repo context. Choose the **parameters** (table below). For the chosen `gate_type`, read **`references/gate-menu.md`**; for the chosen `review_persona`, read **`references/review-personas.md`** (progressive disclosure — don't load them otherwise).
2. Fill **`assets/GOAL.template.md`** -> `GOAL.md`. Then enforce the hard budget:
   `python3 scripts/char_guard.py GOAL.md` — if it prints `OVER`, **recompress and re-run until `OK`** (deterministic gate, never model judgment — this kills the recurring "this is 5039 chars; not 4k" correction).

### Phase B — SCAFFOLD + BUILD TOPOLOGY (do)
3. `bash scripts/scaffold.sh --project <name> [--arc <name>] [--mode tmpdir|in-repo|inline]` — capture the **last stdout line** (the resolved `<root>`).
4. **Build the topology first.** Decompose the target into typed task-unit nodes **grounded in real code (`file:line`), reuse-first**. Each node is an `<article class="node" id=… data-deps=… data-status=… data-files=… data-verify=…>` element in `<root>/topology.html` (graph metadata) plus a prose spec at `nodes/<id>.md` (from **`assets/node.template.md`**). Fan out **one map-agent per candidate node** to fill them. *Single-spawner: you schedule + read; the agents fill.*
5. `python3 <root>/validate.py <root>/topology.html` — must print `OK` (acyclic, no dangling refs); it emits `build_order` + Kahn-layered `waves`. **Block until green.**

### Phase C — DRIVE (loop until the frontier empties) — *workflows + parallelism live here*
> **Autostart is `full-auto` by default** (`topology.html` → `<meta name="th:autostart">`): once `validate.py` is green, flow straight into the loop below with **no checkpoint**. Set `gate-once` to approve the topology first, or `per-wave` to pause between waves. Stop-hook runs are full-auto by nature.
6. `python3 <root>/frontier.py <root>/topology.html` -> plain-text `ready: …` / `clusters: …` / `isolate: …` / `blocked: …` / `done: N/M` (status read straight from each node's `data-status` — single source of truth).
7. **Shard the ready set and fan out concurrently.** A single Workflow runs only `min(16, cores−2)` agents at once, so to wield the full `th:max-parallel` width, split the wave across Workflows. Run `python3 <root>/frontier.py <root>/topology.html --shard <K>` (K ≈ one Workflow's agent ceiling, ~12–16) → it prints `shards: <n>` then one `shard:` line each. **Launch one Workflow per `shard:` line in the same turn** (multiple `Workflow` tool calls → they run in the background concurrently), each generated from **`assets/workflow.template.js`** with
   `args = { root, config, wave: <that shard's nodes with their specs>, skeptics }`.
   With width 448 that is up to ~32 Workflows × ~14 agents ≈ hundreds in flight. Each Workflow fans `map -> do -> review -> gate` **per node with maximal parallelism** (`pipeline`; a `parallel` barrier only when `frontier_mode === "waves"`). **Worktree isolation is applied automatically** to any node `frontier.py` flagged in `isolate` — so file-sharing nodes are safe *even across different shards/Workflows*. Wait for every shard-Workflow to report before writing back.
8. **Write back:** set each node's `data-status` in `topology.html` (`done`|`gate_fail`|`killed`) and append `FINDINGS.md`; promote every `pass-with-followup` into a fully-spec'd new node (a new `<article class="node">` in `topology.html` + `nodes/<id>.md` + hyperedge). **Re-read `GOAL.md` before planning the next wave.** Go to 6.
9. When `ready` is empty and all nodes are `done`: run the **FINAL INTEGRATED adversarial review** — one Workflow over the *whole* change set. This **supersedes the per-stage checklists** (a per-stage checklist is not enough; the integrated review catches what stage reviews miss). Then the **human lands commits**.
10. *(optional autonomy)* `bash scripts/install_stop_hook.sh --root <root>` — installs a session-scoped Stop hook that re-injects `GOAL.md` and blocks termination until the frontier empties, so the loop self-continues across context exhaustion. Human sign-off gates remain and are overridable. Without `--apply` it only prints the settings block.

## The `map -> do -> review` state machine (frozen core; what `workflow.template.js` runs)

- **S0 BUILD_TOPOLOGY** -> nodes + typed hyperedges `{fanout|join|gate|enables}` + waves; acyclicity + dangling check (`validate.py`); emit `topology.html`. -> S1
- **S1 COMPUTE_FRONTIER** -> ready-set `{ deps all done AND gates open AND status not in {done,killed} }`, partitioned into independent clusters (`frontier.py`). Empty => S_EXIT.
- **S2 FANOUT** -> shard the ready set (`frontier.py --shard K`) and launch **one Workflow per shard, concurrently** (≈ `th:max-parallel`/K Workflows × K agents); worktree-isolate shared-file writers; the orchestrator stays out of the work.
- **S3 MAP** (read-only) -> schema'd change-spec + acceptance gate + bound invariants. Premise false => `status = killed` => S1.
- **S4 DO** -> implement (executor `claude` writes directly, or `codex` delegates to the Codex CLI via `codex_exec.sh`), reuse-over-rebuild, isolated worktree, return a diff.
- **S5 REVIEW** -> fan out *N* independent adversarial skeptics (one per dimension), each returns the verdict schema. All pass => S6; any fail => S4; pass-with-followup => S6 + spawn node.
- **S6 GATE** -> DONE iff REVIEW passed AND the runnable **Verify** is green (per-track) AND no sibling regressed. **Honest gate:fail is a first-class success — never fake-pass.**
- **S7 WRITEBACK** -> append status + findings; followups become nodes; re-read driver. -> S1
- **S_EXIT** -> frontier empty / every node DONE AND Verify green. **Operator boundary (invariant): the human lands commits; the model implements + tests.**

## Directory contract (`scaffold.sh` writes this; `tmpdir` mode by default)

```
<root>/                     # ${TMPDIR:-/tmp}/<project>_hypergraph
  topology.html             # AUTHORITATIVE graph + its own rendered view (open in a browser):
                            #   nodes      = <article class="node" data-status/deps/files/verify/…>
                            #   hyperedges = <div class="hyperedge" data-kind/members/…>
                            #   config     = <meta name="th:*"> (autostart, frontier-mode, budgets…)
  GOAL.md                   # the sub-4k drive prompt (== Stop-hook condition)
  FINDINGS.md               # append-only findings + per-node outcomes
  REVIEW.md                 # review fixes + deferred minors
  nodes/<id>.md             # ONE prose task-unit spec per node (assets/node.template.md)
  validate.py frontier.py char_guard.py codex_exec.sh   # copied here for standalone use
  maps/                     # optional code-cohesion / test-map (grounds Verify cmds)
```
**No JSON anywhere — structure is HTML, prose is markdown.** Node **status lives only in `topology.html`** (`data-status`). Not part of the contract (harness-owned): the per-subagent `<id>.output` blobs under `/private/tmp/.../tasks/`.

## Parameters (per-project knobs — global ones in `topology.html` `<meta name="th:*">`, per-node ones in each node's `data-*`; freeze nothing here)

| param | values (default **bold**) |
|---|---|
| `mode` (substrate) | **tmpdir** · in-repo · inline (single-pass, no file) |
| `autostart` | **full-auto** (no checkpoint) · gate-once (approve topology, then flow) · per-wave |
| `frontier_mode` | **stream** (pipeline, no barrier) · waves (hard barrier per stage) |
| `executor` | **claude** (DO implements directly) · codex (DO delegates to the Codex CLI) |
| `codex_model` | model slug when `executor=codex` (default **gpt-5.5**); per-node `data-executor` / `data-codex-model` override |
| `id_scheme` *(per-node)* | **cluster** (A1..E4) · kebab (runs-schema) · arc-stage (K1..K5) |
| `status` *(per-node)* | **todo/doing/done/blocked/killed** |
| `gate_type` *(per-node/track)* | golden-diff · intentional-diff+flag · test-green · forgeability — see `references/gate-menu.md` |
| `verify` *(per-node/track)* | the runnable cmd (pytest+geometry-hash · vitest+svelte-check · npm test:mcp …) |
| `review_persona` | **skeptic** · brutalist · security · layered — see `references/review-personas.md` |
| `autonomy_mode` | **manual** · stop-hook |
| `tracks[]` | single · multi-track with *different* per-track gates |

Invariant (not a knob): **single-spawner orchestration**, **worktree isolation for shared-file writers**, **final integrated review**, **honest gates**, **human lands commits**, **GOAL ≤ char_budget**, **maximize parallelism**.

## Bundled resources

- `scripts/scaffold.sh` — writes the directory contract; copies the helpers beside the graph.
- `scripts/char_guard.py` — hard `< char_budget` gate on `GOAL.md`.
- `scripts/validate.py` — Kahn acyclicity + dangling-ref check over `topology.html`; emits `build_order` + `waves`.
- `scripts/frontier.py` — parses `topology.html`; prints the ready-set, parallelizable clusters, and `isolate` flags.
- `scripts/install_stop_hook.sh` — installs/uninstalls the autonomy Stop hook (conservative; `--apply` to edit settings).
- `scripts/codex_exec.sh` — Codex-CLI executor adapter (the one place codex `exec`/`resume` flags live; runs as your own OpenAI auth). The DO stage drives it when `executor=codex`; it parses codex's JSONL and **exits non-zero on a codex error so the gate fails honestly**.
- `assets/topology.template.html` — the **self-rendering** topology (graph data + embedded DAG visualization; open in a browser).
- `assets/GOAL.template.md` — the sub-4k drive-prompt template.
- `assets/node.template.md` — the prose task-unit spec template (objective / inputs / agent-prompt / acceptance / verify / evidence).
- `assets/workflow.template.js` — the parameterized `map/do/review` Workflow engine the skill **generates and runs** (its inline `VERDICT_SCHEMA` is the canonical review verdict).
- `references/gate-menu.md`, `references/review-personas.md` — progressive-disclosure menus.
- `~/.claude/commands/goal.md` — thin `/goal` slash-command front door.
