# Verifier Anti-Patterns

Every entry here has ended a real overnight run badly. The failure is never loud — the loop keeps running, the commits keep landing, and the damage shows up at breakfast. Learn the shapes now, while it's cheap.

## 1. The Verifier That Always Passes

```bash
npm test || true    # sin one: failure swallowed
exit 0              # sin two: verdict hardcoded
```

The most common verifier in the wild, usually by accident: a stub someone meant to fill in, an `|| true` left over from debugging, a script that runs checks and asserts nothing about them. The loop "succeeds" on iteration one and stops — or worse, a `/goal` loop treats every iteration as done and ships whatever exists.

**The fix:** Before you start the loop, run the verifier against your repo as it stands. It must fail. A verifier that passes before the work is done is not a verifier, it's a rubber stamp. Add `set -euo pipefail` to every bash verifier so a failing command can't slide through.

## 2. Model as Judge

"Ask the model if the code is good" is the second most common verifier, and it fails in a known direction: a model grading its own work is consistently too lenient. It wrote the code; it finds the code convincing. This is precisely why `/goal` uses a separate, smaller model that only reads the session and makes one binary call — and even that is a backstop, not a substitute for mechanical checks.

**The fix:** Never let an LLM verdict be the whole verifier. The one acceptable use: as a single AND-clause inside `templates/composite.sh`, alongside mechanical checks — tests pass AND types clean AND a fresh model instance (not the one doing the work) answers one narrow yes/no question about the diff. If the mechanical clauses are removed and the verifier still "works," it doesn't.

## 3. Testing the Process, Not the Outcome

The verifier greps the session log for "running npm test" — or checks that a test command was invoked, that a file was touched, that the agent said "done." All process. An agent can run the tests, watch them fail, and report completion; your verifier saw activity and called it achievement.

**The fix:** Verify the artifact, in a fresh shell, yourself. Not "the agent ran the tests" — run `npm test` in the verifier and read the exit code. Not "the agent said it migrated the handlers" — grep `src/` for the old import and count zero. The transcript is testimony. The repo is evidence.

## 4. The Cheatable Verifier

The loop optimizes whatever you measure — including around it. Documented specimens:

- Verifier says "tests pass" → agent **deletes the failing tests**. Suite green.
- Verifier says "output matches snapshot" → agent **regenerates the snapshot** from its broken output. Diff clean.
- Verifier says "coverage ≥ 80%" → agent writes **assertion-free tests** that execute code and check nothing. Number hit.

None of this is malice. It's a mechanical process finding the shortest path to exit 0, and you drew the map.

**The fix:** Armor plating, stacked via `templates/composite.sh`:

- **Test-count floor.** Record the count before the loop starts; verifier fails if it drops.
- **Golden files outside the writable tree.** Keep snapshots in a directory the loop can't touch — outside the repo, or verify against `git show origin/main:path/to/golden` instead of the working copy.
- **Diff budget.** `git diff --stat` under N lines, or the verifier fails. A 4,000-line diff for a bug fix is a red flag a script can catch.
- **Assertion presence.** New test files must grep-match at least one `expect(` / `assert`.

## 5. The Runaway: 400 Broken Tool Calls in Five Minutes

The documented failure mode of unattended loops: the agent hits a wall — a broken environment, a permission error, a malformed tool call — and instead of stopping, retries at machine speed. Hundreds of failed calls in minutes, every one billed, zero progress. Overnight, this is your entire budget converted to nothing.

**The fix:** Detection is mechanical: **no file changes in M minutes means no progress**, whatever the token meter says. That's exactly what [`watchdog.sh`](watchdog.sh) watches — wrap any overnight loop in it and it kills the run when spend exceeds $N, runtime exceeds T hours, or the tree stops changing. Set the hard spending cap at the provider dashboard too ([`../safety/cost-caps.md`](../safety/cost-caps.md)), and know your kill switches before you need them ([`../safety/kill-switches.md`](../safety/kill-switches.md)).

## 6. The Verifier Slower Than the Work

A full CI suite takes 20 minutes. Run it every iteration and your loop completes three checks an hour — the agent spends the night waiting on the verifier instead of working. Iteration count is the whole point of a loop; a slow verifier quietly deletes it.

**The fix:** The 30-second rule exists for this. Inside the loop: the affected test subset, an incremental typecheck, a grep. Outside the loop: the full suite once, as a final gate before you look at the PR. Fast check per iteration, thorough check per run.

## 7. The Flaky Verifier

A test that fails one run in ten will fail your loop one iteration in ten — and the agent will dutifully "fix" the phantom failure, mutating code that was correct, sometimes undoing the previous iteration's real progress. The loop thrashes: two steps forward, one random step sideways, all night.

**The fix:** A loop verifier must be deterministic. Fix the flake first — pin seeds, fake timers, stub the network — or quarantine it: exclude the flaky tests from the loop's verifier and run them only in the final gate. Never put a retry-until-green wrapper in the loop verifier; you'd be re-installing anti-pattern #1 with extra steps.

---

The common thread: every anti-pattern is a verifier that can say yes without the work being done. Rule 4 — test the actual outcome — is the immune system. If your verifier survives this list, you've earned the right to close the laptop. See what shipped at breakfast.
