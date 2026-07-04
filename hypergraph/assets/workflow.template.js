/**
 * workflow.template.js — wave-runtime Workflow for the task-hypergraph skill.
 *
 * THIS FILE IS AN ASSET / TEMPLATE for the Claude Code **Workflow tool**. The
 * orchestrator copies/adapts it and passes it to Workflow({script}) once per
 * ready wave. It targets the Workflow runtime — where `agent`, `parallel`,
 * `pipeline`, `phase`, `log`, `args`, and `budget` are injected globals and the
 * script body runs in an async context (top-level `await` and `return` are
 * valid). It is NOT a standalone Node script: `node --check` will flag the
 * top-level return, which is expected and correct for a Workflow script.
 *
 * ──────────────────────────────────────────────────────────────────────────
 * ORCHESTRATOR INVOCATION CONTRACT
 * ──────────────────────────────────────────────────────────────────────────
 * The orchestrator drives one wave per Workflow invocation:
 *
 *   1. run `frontier.py` against topology.html -> the READY set (deps satisfied,
 *      data-status actionable) plus the `isolate` flags. (topology.html is the
 *      single source of truth; node status lives in data-status, no STATUS.md.)
 *   2. pass that ready set to this Workflow as `args.wave` (with `root`,
 *      `config`, and `skeptics`).
 *   3. run THIS Workflow; it returns an array of per-node result records
 *      (shape documented at the entry point below).
 *   4. write the results back to disk (the Workflow itself never does):
 *        - topology.html <- each node's data-status (done|gate_fail|killed)
 *        - FINDINGS.md   <- aggregated review findings + gate detail
 *        - promote each review followup into a new <article class="node"> + hyperedge.
 *   5. recompute the frontier and loop until it is empty (all done/killed) or
 *      stalls on gate_fail.
 *
 * ──────────────────────────────────────────────────────────────────────────
 * AMBIENT `args` SHAPE (injected global)
 * ──────────────────────────────────────────────────────────────────────────
 *   args = {
 *     root: string,                 // absolute workspace/repo root
 *     config: { frontier_mode: "stream" (default) | "waves",
 *               executor: "claude" (default) | "codex", codex_model, ... },
 *     wave: [ Node, ... ],          // the ready nodes for THIS invocation
 *     skeptics: [ Skeptic, ... ],   // adversarial reviewer personas
 *   }
 *
 *   Node = {                         // mirrors a topology.html <article class="node"> (data-*)
 *     id: string,                   // stable node id (the article's id)
 *     specPath: string,             // path to the node's prose spec (nodes/<id>.md)
 *     objective?: string,           // one-line done-condition (node ## Objective)
 *     agentPrompt?: string,         // verbatim self-contained DO-agent prompt (node ## Agent-Prompt)
 *     inputs?: string[],            // upstream artifact paths / file:line anchors this node reads
 *     gate_type?: string,           // golden-diff | intentional-diff+flag | test-green | forgeability
 *     invariants?: string[],        // cross-cutting properties that must stay true
 *     isolate?: boolean|"none"|"worktree", // worktree-isolate shared-file writers (frontier.py sets this)
 *     executor?: "claude"|"codex",  // who runs DO (overrides config.executor)
 *     codex_model?: string,         // codex model slug when executor==="codex"
 *     files?: { existing?: string[], new?: string[] },
 *     verify: string,               // shell command that gates the node (node ## Verify)
 *   }
 *
 *   Skeptic = { id: string, lens?: string }  // adversarial verifier persona
 *
 * ──────────────────────────────────────────────────────────────────────────
 * AMBIENT WORKFLOW HOOKS (injected globals — the REAL Workflow tool API)
 * ──────────────────────────────────────────────────────────────────────────
 *   agent(prompt, opts?) -> Promise<result|null>
 *        prompt: string. opts: { label?, phase?, schema?, model?, effort?,
 *        isolation?: "worktree", agentType? }. With a `schema` the subagent is
 *        forced to return a validated object; without, it returns its final
 *        text. Returns null if the agent is skipped mid-run or dies after
 *        retries — always `.filter(Boolean)` results you fan out.
 *   parallel(thunks) -> Promise<any[]>   run zero-arg async thunks concurrently;
 *        BARRIER (awaits all). A throwing thunk resolves to null (never rejects).
 *   pipeline(items, ...stages) -> Promise<any[]>   thread each item through the
 *        ordered stages INDEPENDENTLY (maximal parallelism — a slow item never
 *        blocks a fast one). Each stage gets (prevResult, originalItem, index).
 *        A stage that throws drops that item to null and skips its rest.
 *   phase(title) -> void                 set the current progress group. Prefer
 *        opts.phase inside parallel()/pipeline() stages to avoid races.
 *   log(msg) -> void                     narrator progress line.
 *
 * The Workflow tool executes this module's top-level body and captures the
 * array it returns.
 */

/* eslint-disable no-undef -- agent/parallel/pipeline/phase/log/args are Workflow globals */

export const meta = {
  name: "task-hypergraph-wave",
  description:
    "Drive one ready wave of a task-hypergraph through map -> do -> review -> gate, " +
    "maximizing parallelism, with adversarial review and honest pass/fail gates.",
  phases: [
    { title: "Map" },
    { title: "Do" },
    { title: "Review" },
    { title: "Gate" },
  ],
};

/* ── Inline JSON schemas (the subagent return is validated against these) ──── */

/**
 * SPEC_SCHEMA — map-stage output. The mapper either KILLS the node (redundant /
 * obsolete / unsafe / already-satisfied) or emits a concrete change plan.
 */
const SPEC_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["kill", "reason", "change_plan", "acceptance", "invariants_bound"],
  properties: {
    kill: {
      type: "boolean",
      description:
        "True iff the node should NOT be built (redundant, obsolete, unsafe, or already satisfied).",
    },
    reason: {
      type: "string",
      description: "Why the node is killed, or the one-line rationale for building it.",
    },
    change_plan: {
      type: "array",
      items: { type: "string" },
      description: "Ordered, concrete implementation steps. Empty when kill=true.",
    },
    acceptance: {
      type: "array",
      items: { type: "string" },
      description: "Observable acceptance criteria a reviewer can independently check.",
    },
    invariants_bound: {
      type: "array",
      items: { type: "string" },
      description: "Cross-cutting invariants this node must preserve while changing.",
    },
  },
};

/**
 * BUILD_SCHEMA — do-stage output. What the implementer actually changed on disk.
 */
const BUILD_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["id", "files_touched", "diff_summary"],
  properties: {
    id: { type: "string" },
    files_touched: {
      type: "array",
      items: { type: "string" },
      description: "Absolute or repo-relative paths created or edited.",
    },
    diff_summary: {
      type: "string",
      description: "Tight prose summary of the change actually applied.",
    },
  },
};

/**
 * VERDICT_SCHEMA — review-stage output (the canonical review verdict schema).
 * `verdict` is the decisive field tallied for real_fail.
 */
const VERDICT_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "lens",
    "claim_under_test",
    "verdict",
    "evidence",
    "reasoning",
    "new_followup_nodes",
    "severity",
  ],
  properties: {
    lens: {
      type: "string",
      description: "The review lens / adversarial perspective this verifier adopted.",
    },
    claim_under_test: {
      type: "string",
      description: "The single, specific claim this verdict adjudicates.",
    },
    verdict: {
      type: "string",
      enum: ["claim_holds", "claim_refuted", "partially_refuted"],
      description: "Outcome of testing the claim against the gathered evidence.",
    },
    evidence: {
      type: "array",
      description: "Concrete, citable evidence gathered while testing the claim.",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["file_line", "quote", "what_it_proves"],
        properties: {
          file_line: {
            type: "string",
            description: "Location as path:line (e.g. src/app.py:42) or path:start-end.",
          },
          quote: { type: "string", description: "Verbatim excerpt copied from the cited location." },
          what_it_proves: {
            type: "string",
            description: "How the excerpt supports or undermines the claim under test.",
          },
        },
      },
    },
    reasoning: {
      type: "string",
      description: "Narrative tying the evidence to the verdict: what was checked and why.",
    },
    new_followup_nodes: {
      type: "array",
      description: "Newly discovered tasks spawned by this review. Empty array when none.",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["title", "steps", "missing_check", "works_today"],
        properties: {
          title: { type: "string", description: "Short imperative title for the follow-up node." },
          steps: {
            type: "array",
            items: { type: "string" },
            description: "Ordered, concrete steps to execute the follow-up.",
          },
          missing_check: {
            type: "string",
            description: "The verification currently absent that motivates this follow-up.",
          },
          works_today: {
            type: "boolean",
            description: "Whether the behavior is confirmed working now (true) or broken/unverified (false).",
          },
        },
      },
    },
    severity: {
      type: "string",
      enum: ["none", "low", "medium", "high", "critical"],
      description: "Severity of the issue surfaced. 'none' when the claim holds with no concern.",
    },
  },
};

/**
 * GATE_SCHEMA — gate-stage output. Honest result of running node.verify.
 * status is NEVER fabricated: "done" only when verify genuinely passed.
 */
const GATE_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["id", "status", "gate_detail", "verify_output_tail"],
  properties: {
    id: { type: "string" },
    status: {
      type: "string",
      enum: ["done", "gate_fail"],
      description: "Honest gate outcome. Never fake-pass: report gate_fail on any doubt.",
    },
    gate_detail: {
      type: "string",
      description: "What the gate checked, the command run, and the observed outcome.",
    },
    verify_output_tail: {
      type: "string",
      description: "Trailing lines of the verify command's combined stdout+stderr.",
    },
  },
};

/* ── Stages ───────────────────────────────────────────────────────────────
 * Each stage takes a `ctx` (seeded from a Node) and returns an enriched ctx.
 * A killed ctx is terminal — downstream stages pass it through untouched.
 * The signatures interlock with both pipeline(...) and parallel(...) below.
 */

/** MAP: read the node's spec + inputs; produce a SPEC_SCHEMA plan or KILL it. */
async function mapStage(node) {
  const { root } = args;
  const spec = await agent(
    `Workspace root: ${root}\n` +
      `Read the node spec at ${node.specPath} and every declared input ` +
      `(${(node.inputs || []).join(", ") || "none"}). Decide whether this node ` +
      `should be built at all. KILL it (kill=true) if it is redundant, obsolete, ` +
      `unsafe, or already satisfied by code on disk. Otherwise emit a concrete, ` +
      `reuse-first change plan, acceptance criteria, and the invariants it must hold.`,
    { label: `map:${node.id}`, phase: "Map", schema: SPEC_SCHEMA }
  );
  if (!spec) return { id: node.id, node, status: "killed", killReason: "map agent died" };

  const ctx = { id: node.id, node, spec };
  if (spec.kill) {
    log(`map:${node.id} -> KILLED (${spec.reason})`);
    return { ...ctx, status: "killed" };
  }
  return ctx;
}

/**
 * DO: implement the plan on disk, reuse-first. Runs the node's verbatim
 * Agent-Prompt when present. Builds inside a git worktree for shared-file
 * writers (isolate set and not "none"); else in place.
 */
async function doStage(ctx) {
  if (!ctx || ctx.status === "killed") return ctx;
  const { root, config } = args;
  const { node, spec } = ctx;

  // node.isolate is a boolean flag (or "none"); only false/"none" builds in place.
  const isolate = node.isolate && node.isolate !== "none";
  // Executor: who runs the DO. "claude" (default) implements directly; "codex"
  // delegates to the Codex CLI via the bundled adapter. Per-node overrides config.
  const executor = node.executor || (config && config.executor) || "claude";
  const codexModel = node.codex_model || (config && config.codex_model) || "gpt-5.5";
  // Worktree-isolate shared-file / parallel-conflicting builds.
  const opts = {
    label: `do:${node.id}`,
    phase: "Do",
    schema: BUILD_SCHEMA,
    ...(isolate ? { isolation: "worktree" } : {}),
  };

  let build;
  if (executor === "codex") {
    // The Workflow JS sandbox cannot run shells, so the leaf must be Bash-capable
    // (agentType general-purpose). It is a THIN DRIVER around the adapter — Codex
    // writes the code; the leaf only relays the brief and reports the diff.
    build = await agent(
      `You are a THIN DRIVER around the Codex CLI executor — do NOT write the code yourself; Codex does.\n` +
        `Helper root: ${root}\n` +
        `From the repository working directory, pipe the brief to the adapter (it owns every codex flag):\n` +
        `  printf '%s' "<BRIEF>" | bash ${root}/codex_exec.sh --model ${codexModel} --sandbox workspace-write\n\n` +
        `BRIEF = implement node ${node.id}, reuse-first, touching only this node's files and preserving its invariants:\n` +
        `  change_plan: ${JSON.stringify(spec.change_plan)}\n` +
        `  acceptance:  ${JSON.stringify(spec.acceptance)}\n` +
        `  invariants:  ${JSON.stringify(spec.invariants_bound)}\n` +
        `  full spec:   ${node.specPath}\n\n` +
        `The adapter prints thread_id / model / tokens / Codex's message, and EXITS NON-ZERO on a codex error ` +
        `(usage limit, turn.failed, bad model). If it exits non-zero, do NOT fake success — return a diff_summary ` +
        `quoting the codex failure verbatim so the gate fails it honestly. On success, run \`git diff --stat\` and ` +
        `\`git status --porcelain\` to determine files_touched, then return the BUILD_SCHEMA.`,
      { ...opts, label: `do:codex:${node.id}`, agentType: "general-purpose" }
    );
  } else {
    build = await agent(
      (node.agentPrompt ? `${node.agentPrompt}\n\n— Orchestration constraints —\n` : "") +
        `Workspace root: ${root}\n` +
        `Change plan: ${JSON.stringify(spec.change_plan)}\n` +
        `Acceptance: ${JSON.stringify(spec.acceptance)}\n` +
        `Invariants to preserve: ${JSON.stringify(spec.invariants_bound)}\n\n` +
        `Implement node ${node.id} on disk via Write/Edit/Bash. REUSE existing code ` +
        `before adding new code. Follow the change plan exactly and preserve every ` +
        `bound invariant. Do not touch files outside the node's remit. Report the ` +
        `files you touched and a tight diff summary.`,
      opts
    );
  }
  if (!build) return { ...ctx, status: "gate_fail", gateReason: "do agent died" };

  return { ...ctx, build };
}

/**
 * REVIEW: fan out the adversarial skeptics in parallel; each returns a
 * VERDICT_SCHEMA (or null -> filtered). real_fail iff a strict MAJORITY of
 * returned verdicts REFUTE the completion claim. Follow-ups surfaced here are
 * promoted to nodes by the orchestrator (the "pass-with-followup" path).
 */
async function reviewStage(ctx) {
  if (!ctx || ctx.status === "killed" || ctx.status === "gate_fail") return ctx;
  const { root, skeptics } = args;
  const { node, spec, build } = ctx;

  const verdicts = (
    await parallel(
      (skeptics || []).map((skeptic) => () =>
        agent(
          `You are an adversarial reviewer${skeptic.lens ? ` with the lens "${skeptic.lens}"` : ""}.\n` +
            `Workspace root: ${root}\n` +
            `Node ${node.id} change summary: ${build ? build.diff_summary : "(none)"}\n` +
            `Files touched: ${build ? JSON.stringify(build.files_touched) : "[]"}\n` +
            `Acceptance to test: ${JSON.stringify(spec.acceptance)}\n` +
            `Invariants that must hold: ${JSON.stringify(spec.invariants_bound)}\n\n` +
            `Adversarially verify the CLAIM that node ${node.id} is correct and ` +
            `complete per its acceptance criteria and bound invariants. Try to ` +
            `REFUTE it: hunt for defects, regressions, missed cases, and unmet ` +
            `invariants. Return verdict="claim_refuted" when you find a real defect, ` +
            `"partially_refuted" for a minor or partial gap, or "claim_holds" if it ` +
            `stands. Ground every verdict in file:line evidence and set severity honestly.`,
          { label: `review:${node.id}:${skeptic.id}`, phase: "Review", schema: VERDICT_SCHEMA }
        )
      )
    )
  ).filter(Boolean);

  const refuted = verdicts.filter((v) => v.verdict === "claim_refuted").length;
  const partial = verdicts.filter((v) => v.verdict === "partially_refuted").length;
  const total = verdicts.length;
  const real_fail = total > 0 && refuted * 2 > total; // strict majority refute

  const findings = verdicts
    .filter((v) => v.verdict !== "claim_holds")
    .map((v) => ({
      lens: v.lens,
      verdict: v.verdict,
      severity: v.severity || "none",
      reasoning: v.reasoning,
      evidence: v.evidence || [],
    }));

  // Review-spawned follow-ups; the orchestrator promotes each into a new node.
  const followups = verdicts.flatMap((v) => v.new_followup_nodes || []);

  log(
    `review:${node.id} -> ${refuted} refuted / ${partial} partial / ${total} total ` +
      `(real_fail=${real_fail})`
  );
  return {
    ...ctx,
    review: { real_fail, refuted, partial, total, verdicts, followups },
    findings,
  };
}

/**
 * GATE: run node.verify via Bash and report honestly. The node is "done" only
 * when the verify command genuinely passes AND review did not real_fail. On any
 * failure or doubt the gate returns gate_fail — it NEVER fake-passes.
 */
async function gateStage(ctx) {
  if (!ctx || ctx.status === "killed" || ctx.status === "gate_fail") return ctx;
  const { root } = args;
  const { node, review } = ctx;

  const gate = await agent(
    `Workspace root: ${root}\n` +
      `Run the verification command EXACTLY as given via Bash:\n  ${node.verify}\n` +
      `Report the honest outcome. status="done" ONLY if the command exits 0 and ` +
      `its output shows a genuine pass. On non-zero exit, error output, flakiness, ` +
      `or any doubt, return status="gate_fail". NEVER fabricate a pass. Include the ` +
      `tail of the command output verbatim.`,
    { label: `gate:${node.id}`, phase: "Gate", schema: GATE_SCHEMA }
  );
  if (!gate) return { ...ctx, status: "gate_fail", gateReason: "gate agent died" };

  const passed = gate.status === "done" && !(review && review.real_fail);
  return { ...ctx, gate, status: passed ? "done" : "gate_fail" };
}

/** Collapse a threaded ctx into the per-node record the orchestrator writes back. */
function finalize(ctx) {
  return {
    id: ctx.id,
    status: ctx.status || "gate_fail",
    diff_summary: ctx.build ? ctx.build.diff_summary : null,
    verdict: ctx.review || null,
    gate_detail: ctx.gate ? ctx.gate.gate_detail : ctx.spec ? ctx.spec.reason : null,
    findings: ctx.findings || [],
  };
}

/* ── Entry point (top-level Workflow body) ──────────────────────────────────
 * Returns: Array<{
 *   id, status: "done"|"gate_fail"|"killed", diff_summary, verdict, gate_detail, findings
 * }>
 */
const { config, wave } = args;
const mode = (config && config.frontier_mode) || "stream";
log(`task-hypergraph wave: ${wave.length} node(s), frontier_mode=${mode}`);

let ctxs;
if (mode === "waves") {
  // Hard barrier between stages: every node clears a stage before any node
  // starts the next. Use when a downstream stage needs a fully-settled prior one.
  ctxs = (await parallel(wave.map((n) => () => mapStage(n)))).filter(Boolean);
  ctxs = (await parallel(ctxs.map((c) => () => doStage(c)))).filter(Boolean);
  ctxs = (await parallel(ctxs.map((c) => () => reviewStage(c)))).filter(Boolean);
  ctxs = (await parallel(ctxs.map((c) => () => gateStage(c)))).filter(Boolean);
} else {
  // Default "stream": nodes flow independently through the stages with MAXIMAL
  // parallelism — a slow node never blocks a fast node's gate.
  ctxs = (await pipeline(wave, mapStage, doStage, reviewStage, gateStage)).filter(Boolean);
}

const results = ctxs.map(finalize);
log(`wave complete: ${results.map((r) => `${r.id}=${r.status}`).join(", ") || "(empty)"}`);
return results;
