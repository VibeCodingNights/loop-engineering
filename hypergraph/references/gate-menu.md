# Gate Menu

Every node in the task-hypergraph carries **exactly one gate**. The gate is the
node's definition of done: it names *what must be true* (the `Acceptance:` line)
and *the command that proves it* (the `Verify:` line, which exits `0` iff the
node is done and prints the failing invariant to stderr otherwise).

This file is read **per track** — find your row in the picker, jump to that one
section, and skip the rest.

## Pick a gate

| If the change is...                                  | Gate                       | Go to |
|------------------------------------------------------|----------------------------|-------|
| behavior-preserving (refactor / rename / move / dedup) | **golden-diff**            | [§1](#1-golden--byte-identical-diff) |
| a deliberate, reviewable behavior change             | **intentional-diff+flag**  | [§2](#2-intentional-diff-flag--ledger) |
| new logic, a bugfix, or a feature with test coverage | **test-green**             | [§3](#3-typecheck--test-green) |
| attacker-facing (auth, signing, trust boundary)      | **forgeability**           | [§4](#4-forgeability--security-verdict) |

**Choosing rules**
- If the output *must not move at all*, use **golden** — even for a one-liner.
- If you are *changing* behavior, never weaken to test-green: use
  **intentional-diff** so the change is flagged and ledgered.
- **forgeability** is additive — a security-sensitive node still needs its
  functional gate as a sibling node, but the trust boundary gets its own.

**Invariant naming** — `gate:short-kebab-name`, lowercase, stable across runs so
the diff-ledger and other nodes can reference it by name. Examples per gate below.

---

## 1. Golden — byte-identical diff

**When to use**
- Refactors, renames, file moves, dead-code removal, dependency bumps that
  claim to change *nothing observable*.
- Any node whose pitch contains "no behavior change" / "pure cleanup".

**Acceptance line**
```
Acceptance: {{ARTIFACT}} is byte-identical to baseline (sha256 {{BASELINE_SHA}})
```
When the format carries unavoidable byte noise (timestamps, float formatting,
gzip headers), drop to the structural form and assert the *rendered* result is
stable instead:
```
Acceptance: {{ARTIFACT}} renders identically — bbox {{BBOX}}, solid-count {{N}}
```

**Verify command (shape)** — regenerate, then compare to the committed baseline;
exit non-zero on any drift.
```
# strict bytes
Verify: test "$(sha256sum {{ARTIFACT}} | cut -d' ' -f1)" = {{BASELINE_SHA}}

# structural (byte-noisy formats)
Verify: {{EXTRACT_METRICS}} {{ARTIFACT}} | diff - {{GOLDEN_METRICS}}
```
`{{EXTRACT_METRICS}}` emits the stable signature (e.g. `bbox` + `solid-count`)
so transient bytes never trip the gate but a moved pixel does.

**Example named invariants**
- `golden:sha256-match` — output hash equals the committed baseline.
- `golden:bbox-stable` — rendered bounding box unchanged.
- `golden:solid-count` — number of solid/filled regions unchanged.

---

## 2. Intentional-diff (flag + ledger)

**When to use**
- A *deliberate* behavior change you want reviewable and reversible.
- Anything that would fail a golden gate **on purpose** — new output, changed
  copy, tuned thresholds, migrated formats.

The change lands behind a feature flag (default **off**), and the new-vs-old
delta is recorded as a row in the **diff-ledger**. The gate proves two things at
once: nothing moves with the flag off, and the flag-on delta is exactly the
ledgered one.

**Acceptance line**
```
Acceptance: flag {{FLAG}} off => golden({{ARTIFACT}}); on => diff matches ledger {{LEDGER_ID}}
```

**Verify command (shape)**
```
Verify: {{FLAG}}=0 {{BUILD}} && test "$(sha256sum {{ARTIFACT}} | cut -d' ' -f1)" = {{BASELINE_SHA}} \
     && {{FLAG}}=1 {{BUILD}} && {{DIFF}} {{BASELINE}} {{ARTIFACT}} | diff - {{LEDGER_DIR}}/{{LEDGER_ID}}.diff
```
Off-path must stay byte-identical (reuse the golden check). On-path must produce
a diff equal to the ledger entry — no more, no less. A drift on *either* side
fails; an unledgered change is a fail, not a pass.

**Example named invariants**
- `flag-off:golden` — disabled path is byte-identical to baseline.
- `flag-on:ledger-match` — enabled-path diff equals the recorded ledger entry.
- `ledger:entry-present` — `{{LEDGER_ID}}` exists and is non-empty.

---

## 3. Typecheck + test-green

**When to use**
- New logic, bugfixes, or features that carry their own tests.
- The default gate when output legitimately changes and is covered by tests
  rather than a golden baseline.

**Acceptance line**
```
Acceptance: type-clean and tests green ({{SUITE}}); covers {{BEHAVIOR}}
```

**Verify command (shape)** — typecheck first (cheap, fails fast), then the suite;
any non-zero exit fails the gate.
```
# svelte / ts
Verify: npx svelte-check --fail-on-warnings && npx vitest run {{TEST_GLOB}}

# python
Verify: pyright {{PKG}} && pytest -q {{TEST_PATH}}

# generic
Verify: npm run typecheck && npm test
```
Prefer a *scoped* test selector (`{{TEST_GLOB}}` / `{{TEST_PATH}}`) so the gate
proves *this* node, not the whole repo — but never skip the typecheck.

**Example named invariants**
- `types:clean` — typechecker reports zero errors (and zero warnings if enforced).
- `unit:green` — the node's unit tests pass.
- `e2e:green` — end-to-end / integration suite passes (when applicable).

---

## 4. Forgeability — security verdict

**When to use**
- Auth, token issuance/verification, signatures, capability checks, any trust
  boundary an attacker can poke.
- The verdict is adversarial: the node is done only when **no break-vector
  succeeds**. A passing functional test is necessary but not sufficient here.

**Acceptance line**
```
Acceptance: no break-vector forges a valid {{ASSET}}; all of {{VECTORS}} rejected
```

**Verify command (shape)** — run the adversarial harness; it exits `0` only when
every break-vector is *rejected* (a forged success is a non-zero exit).
```
Verify: {{HARNESS}} --target {{COMPONENT}} --vectors {{VECTORS_FILE}}
```
The harness enumerates break-vectors (replay, tamper, downgrade, confused-deputy,
expiry-bypass, signature-strip) and asserts each is denied. Add a vector for
every fix you ship so the verdict never silently narrows.

**Example named invariants**
- `forge:replay-rejected` — a captured-and-replayed credential is denied.
- `forge:tamper-rejected` — a payload mutated post-signature is denied.
- `forge:downgrade-blocked` — `alg=none` / weaker-cipher coercion is denied.
- `forge:expiry-enforced` — an expired or not-yet-valid token is denied.
