# Is Your Goal Mechanically Checkable?

A loop goal is only as good as its exit condition. "Make the tests pass" works because a script can check it. "Improve the code" fails because the loop never knows when to stop. Before you start a loop, run your goal through this tree.

## The Decision Tree

```
Can a script check it — zero human judgment anywhere in the check?
│
├── NO → Is it actually several goals wearing one sentence?
│        ("production-ready" = tested + typed + documented + deployed)
│   │
│   ├── YES → DECOMPOSE IT. Split into goals that each get their
│   │         own verifier. Loop on them one at a time, or in
│   │         parallel (see ../patterns/06-parallel-agents.md).
│   │
│   └── NO  → MAKE IT MECHANICAL. Find the proxy artifact a script
│             can inspect: an AST, a benchmark number, a schema, a
│             golden file. Most "subjective" goals have one — see
│             examples 6, 8, 11, 14 below. If no proxy exists,
│             it is not a loop goal. Do it by hand.
│
└── YES → Does the check finish in under 30 seconds?
    │
    ├── NO → TIGHTEN IT. Run the affected test subset, not the
    │        whole suite. Cache the build. Check one module. Keep
    │        the slow full check as a final gate, outside the loop.
    │
    └── YES → Does it test the outcome, not the process?
        │
        ├── NO → REWRITE IT. Check the artifact ("tests pass"),
        │        never the activity ("the agent ran the tests").
        │        See anti-patterns.md #3.
        │
        └── YES → Can it pass by accident, or by cheating?
            │    (Agent deletes the failing test. Hardcodes the
            │     snapshot. Writes assertion-free tests for coverage.)
            │
            ├── YES → ARMOR IT. Composite checks (templates/composite.sh),
            │         a test-count floor, a diff budget, golden files
            │         outside the writable tree. See anti-patterns.md #4.
            │
            └── NO → USE IT. Wire it in. Start the loop.
```

## Fifteen Goals, Judged

### 1. "Make the tests pass"

**Verdict: good.** `npm test` exits 0 or it doesn't. Fast, binary, no judgment. This is the canonical good goal — copy `templates/test-pass.sh`. One caveat: it's cheatable by deleting tests, so add a test-count floor for overnight runs.

### 2. "Get the typecheck clean"

**Verdict: good.** `npx tsc --noEmit` or `mypy .` is a pure exit-code check. Nearly uncheatable — the agent can't delete the type system. Copy `templates/type-check.sh`.

### 3. "Migrate off Express — no Express imports remain in src/, and it still compiles"

**Verdict: good.** Two mechanical clauses: grep count equals zero, typecheck passes. This is the shape of every migration verifier. Copy `templates/no-pattern.sh` and AND it with `type-check.sh` via `composite.sh`.

### 4. "Coverage at or above 80%"

**Verdict: good — armor it.** The number is mechanical (`templates/coverage-threshold.sh`). But coverage is the most gameable metric in software: an agent can hit 80% with assertion-free tests that execute code and check nothing. AND it with "tests pass" and a grep for at least one `expect`/`assert` per new test file.

### 5. "All 12 endpoints conform to the OpenAPI spec"

**Verdict: good.** Schema conformance is a semantic check that's still fully mechanical — request each endpoint, validate the response against the spec, exit 0 on twelve passes. Copy `templates/api-conformance.py`.

### 6. "Make it faster"

**Verdict: bad, fixable.** Faster than what? Measured how? The loop never knows when to stop — it will "optimize" forever.
**Rewrite:** "The benchmark in `bench/` completes in under 200ms on this machine, and the test suite still passes." Now it's a number and an exit code:

```bash
MS=$(node bench/run.js)          # prints milliseconds
[ "$MS" -lt 200 ] && npm test
```

### 7. "Improve readability"

**Verdict: bad — mostly unfixable.** Readability is a judgment call between two competent humans, let alone a script. Lint rules catch a thin mechanical slice (line length, complexity ceilings), but a loop chasing "readable" will churn your codebase into whatever the model finds statistically pleasant. Don't loop on this. If you must, loop on the lint config and review the rest by hand.

### 8. "Fix the bug"

**Verdict: bad, fixable — and the fix is the whole method.** "Fix the bug" gives the loop no way to know the bug is fixed.
**Rewrite:** First write a failing test that reproduces the bug. You do this part, by hand — it's ten minutes. Then the goal is "make `test/repro-issue-341.test.js` pass without breaking the rest of the suite." Now the verifier is example 1, and the bug's definition is pinned in code instead of in your head.

### 9. "Output matches the golden snapshot"

**Verdict: good — armor it.** Byte-for-byte comparison against a known-good file is fast and binary (`templates/snapshot-diff.sh`). The one failure mode: the agent regenerates the snapshot to match its broken output. Keep golden files outside the loop's writable tree. See anti-patterns.md #4.

### 10. "Refactor this module safely"

**Verdict: bad, fixable.** "Safely" is not checkable; "refactor" has no endpoint.
**Rewrite:** Pin the behavior first — a characterization test suite that captures current outputs. Then: "tests in `test/pin/` all pass, the public API exports are unchanged (diff the `.d.ts`), and the total diff is under 400 lines." Behavior pinned, blast radius bounded, exit condition mechanical.

### 11. "Improve the docs"

**Verdict: bad, fixable.** "Improved" according to whom?
**Rewrite:** "Every exported function has a doc comment." That's an AST parse: walk the exports, check each has a JSDoc/docstring block attached, exit 1 on the first bare one. Seems subjective; is mechanical. Most documentation goals decompose this way — coverage of a countable thing, not quality of prose.

### 12. "Improve the code"

**Verdict: bad.** The canonical bad goal. No definition of improved, no endpoint, no failure state — the verifier would have to be a taste oracle. A loop given this goal runs until your budget dies, rewriting things that worked. If you're tempted by this goal, you haven't picked a task yet. Go pick one.

### 13. "Upgrade React 17 to 18"

**Verdict: good.** Three clauses, all mechanical: `npm ls react` resolves to 18.x, the test suite passes, the build is clean. Dependency upgrades are among the best overnight loop tasks — boring, bounded, fully checkable. Chain the three templates with `composite.sh`.

### 14. "Make the app more accessible"

**Verdict: bad, fixable.** "More accessible" has no stop condition.
**Rewrite:** "`axe-core` reports zero violations on these five routes." An automated a11y scanner turns the goal into a violation count, and a count can be zero. It won't catch everything a human audit would — but it's a real floor, and a loop can drive it to zero unattended.

### 15. "Make it production-ready"

**Verdict: bad — decompose.** This is five goals in a trench coat: tests pass, types clean, no critical `npm audit` findings, build succeeds, health endpoint returns 200. Each of those is verifiable tonight. The composite of all five is a real definition of "production-ready" — which is exactly the point. Write the checklist, verify each line, AND them together. The trench coat was never checkable; the contents always were.

---

The pattern across all fifteen: good goals name an artifact and a threshold. Bad goals name a direction. Fixable goals are bad goals where the artifact exists but you haven't named it yet — naming it is the work. Do that work before you start the loop, not at breakfast.
