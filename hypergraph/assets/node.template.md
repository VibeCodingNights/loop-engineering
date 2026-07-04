<!-- ───────────────────────────────────────────────────────────────────────────
     task-hypergraph NODE SPEC (prose). One node = one independently-executable,
     independently-verifiable unit of work.

     The GRAPH METADATA for this node — id, status, deps, blocks, files, track,
     gate, verify, isolate, risk — lives in topology.html as data-* attributes
     on this node's <article class="node"> element (the SINGLE source of truth).
     This .md file is the human/agent-facing SPEC the DO-agent executes.

     Paired element in topology.html (orchestrator keeps the two in sync):
       <article class="node" id="{{ID}}" data-status="todo" data-type="{{TYPE}}"
                data-track="{{TRACK}}" data-deps="{{DEP_IDS}}" data-blocks="{{BLOCKED_IDS}}"
                data-files="{{FILES}}" data-isolate="{{ISOLATE}}" data-risk="{{RISK}}"
                data-gate="{{GATE_TYPE}}" data-verify="{{VERIFY_CMD}}"
                data-spec="nodes/{{ID}}.md">
         <h3>{{ID}} — {{TITLE}}</h3>
         <p class="objective">{{ONE_LINE_OBJECTIVE}}</p>
       </article>
     ─────────────────────────────────────────────────────────────────────────── -->

# {{ID}} — {{TITLE}}

## Objective

{{OBJECTIVE}}

<!-- 1-3 sentences: what this node accomplishes and why it exists in the graph.
     State the done-condition in plain language. No implementation detail here. -->

## Inputs

Everything this node consumes. Pin concrete `file:line` anchors and name the
upstream node (by id) whose **## Outputs** each dependency comes from.

- `{{INPUT_FILE}}:{{LINE}}` — {{WHAT_THIS_PROVIDES}}
- from `{{UPSTREAM_NODE_ID}}` → {{OUTPUT_NAME}}: {{HOW_THIS_NODE_USES_IT}}

## Outputs

Everything this node produces that downstream nodes (its `data-blocks`) consume.

- {{OUTPUT_NAME}} → `{{OUTPUT_LOCATION}}` — {{DESCRIPTION}}

## Agent-Prompt

> Verbatim, self-contained prompt a workflow DO-agent runs to EXECUTE this node.
> It must stand alone: assume the agent has NOT read the graph, the rest of this
> file, or the conversation. Inline every path, command, and constraint it needs.

{{AGENT_PROMPT}}

<!-- Recommended shape: Context (the one-paragraph "why" + the single area in
     scope) · Reuse (explicit paths the agent MUST build on, not duplicate) ·
     Task (numbered imperative steps writing the data-files) · Constraints (the
     bound invariants as hard rules; what NOT to touch) · Done when (the Verify
     command exits 0 and Acceptance is met). -->

## Acceptance

- [ ] {{ACCEPTANCE_CRITERION_1}}
- [ ] {{ACCEPTANCE_CRITERION_2}}
- [ ] Invariants hold: {{INVARIANT}}
- [ ] `## Verify` command exits 0

## Verify

```bash
{{VERIFY_CMD}}
```

Expected: {{EXPECTED_RESULT}} (exit 0 = pass; non-zero = node not done). This
mirrors the node's `data-verify` in topology.html.

## Evidence

> Filled during review. One entry per Acceptance checkbox / invariant, each
> citing a real `file:line` and the exact quote that proves the claim.

- file_line: `{{EVIDENCE_FILE}}:{{EVIDENCE_LINE}}`
  quote: "{{EVIDENCE_QUOTE}}"
  what_it_proves: {{WHAT_IT_PROVES}}

<!-- ───────────────────────── FILLED EXAMPLE (guidance only) ─────────────────────
Paired topology.html element:
  <article class="node" id="n-017-parse-config" data-status="todo" data-type="impl"
           data-track="core" data-deps="n-004-config-schema" data-blocks="n-031-cli-wiring"
           data-files="src/app/config.py tests/test_config.py" data-isolate="true"
           data-risk="low" data-gate="test-green"
           data-verify="python -m pytest tests/test_config.py -q"
           data-spec="nodes/n-017-parse-config.md">
    <h3>n-017-parse-config — Add YAML config parser with defaults</h3>
    <p class="objective">Load &amp; validate app.yaml into a typed Config for the CLI.</p>
  </article>

# n-017-parse-config — Add YAML config parser with defaults

## Objective
Load and validate `app.yaml` into a typed Config object so the CLI (n-031) can
boot from a single file. Done when invalid configs fail loudly and valid ones
parse with defaults applied.

## Inputs
- `src/app/schema.py:12` — `ConfigSchema` field definitions and defaults
- from `n-004-config-schema` → ConfigSchema: the dataclass this parser populates

## Outputs
- load_config() → `src/app/config.py:1` — returns validated `Config`, raises `ConfigError`

## Agent-Prompt
You are implementing a config loader for a Python CLI. Scope: create
`src/app/config.py` and `tests/test_config.py` only. Reuse `ConfigSchema` from
`src/app/schema.py` (do NOT redefine fields). 1) Write `load_config(path)` that
reads YAML, applies `ConfigSchema` defaults for missing optional keys, and raises
`ConfigError` on any unknown key. 2) Add pytest cases: valid file,
missing-optional→default, unknown-key→raises. Touch no file outside the two
listed. Done when `python -m pytest tests/test_config.py -q` exits 0.

## Acceptance
- [ ] load_config returns a populated Config for a valid app.yaml
- [ ] Unknown key raises ConfigError
- [ ] Missing optional key uses ConfigSchema default
- [ ] python -m pytest tests/test_config.py -q exits 0

## Verify
```bash
python -m pytest tests/test_config.py -q
```
Expected: 3 passed, exit 0.

## Evidence
- file_line: `src/app/config.py:24`
  quote: "raise ConfigError(f\"unknown key: {k}\")"
  what_it_proves: Unknown keys fail loudly (invariant 1)
─────────────────────────────────────────────────────────────────────────────── -->
