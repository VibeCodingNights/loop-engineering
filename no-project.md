# No Project? Take One of These.

Ten real repos with open issues shaped for loops: failing tests, lint debt, type errors, formatting bugs — outcomes a script can check.
How to pick: smallest mechanically-checkable task wins. An issue you can verify with one command beats an interesting one you can't. Not sure your pick qualifies? Run it through [verifiers/good-vs-bad.md](verifiers/good-vs-bad.md).
Clone, run the setup line, and confirm your verifier **fails before you start the loop**. A verifier that fails first and passes after is proof the loop did something.

Issue counts were checked July 2026. Counts drift; the label links stay current. Read each repo's CONTRIBUTING.md before opening a PR — a loop that ships an unwanted PR is spam.

---

## 1. tldr-pages/tldr

Simplified man pages. Thousands of Markdown files, one strict style guide.

- **Why it loops:** every page is independent. Style violations and missing examples are mechanically detectable — the lint suite is the spec. The easiest first loop in this list.
- **Issues:** [help wanted](https://github.com/tldr-pages/tldr/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22) (188 open at last check)
- **Setup:** `npm ci`
- **Verifier:** `npm test` (runs tldr-lint and markdownlint over every page)

## 2. python/mypy

The Python type checker. Pure Python, pip-installable dev environment.

- **Why it loops:** bug reports arrive as minimal code samples with expected-vs-actual output, and the test suite is data-driven `.test` files. Turn the report into a failing test case, loop until green.
- **Issues:** [good-first-issue](https://github.com/python/mypy/issues?q=is%3Aissue+is%3Aopen+label%3Agood-first-issue) (9 open at last check)
- **Setup:** `python3 -m pip install -r test-requirements.txt`
- **Verifier:** `python3 -m pytest -q -n0 -k <your_test_case>`

## 3. sympy/sympy

Computer algebra in pure Python. `pip install -e .` and you're running.

- **Why it loops:** most issues are "this expression evaluates wrong." Write the failing assert first — that assert is your exit condition.
- **Issues:** [Easy to Fix](https://github.com/sympy/sympy/issues?q=is%3Aissue+is%3Aopen+label%3A%22Easy+to+Fix%22) (54 open at last check)
- **Setup:** `python3 -m pip install -e . && python3 -m pip install pytest`
- **Verifier:** `python3 -m pytest sympy/<module>/tests -q -k <case>`

## 4. pylint-dev/pylint

The Python linter. False positives are its most common bug class.

- **Why it loops:** checker behavior is pinned by functional test files with golden expected output. A false-positive fix is: add the input, loop until the golden output matches.
- **Issues:** [Good first issue](https://github.com/pylint-dev/pylint/issues?q=is%3Aissue+is%3Aopen+label%3A%22Good+first+issue%22) (16 open at last check)
- **Setup:** `python3 -m pip install -e . && python3 -m pip install -r requirements_test.txt`
- **Verifier:** `python3 -m pytest tests/test_functional.py -k <checker_name>`

## 5. sphinx-doc/sphinx

The documentation generator behind most of Python's docs.

- **Why it loops:** builder and directive bugs reproduce as small test projects inside the pytest suite. Targeted runs are fast.
- **Issues:** [good first issue](https://github.com/sphinx-doc/sphinx/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22) (13 open at last check)
- **Setup:** `python3 -m pip install -e ".[test]"`
- **Verifier:** `python3 -m pytest tests -q -k <name>`

## 6. prettier/prettier

The code formatter. Formatting bugs are the purest loop food there is.

- **Why it loops:** the entire test suite is Jest snapshots — input file in, formatted output compared against a golden file. Add the failing input, loop until the snapshot is right.
- **Issues:** [help wanted](https://github.com/prettier/prettier/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22) (50 open at last check)
- **Setup:** `yarn install`
- **Verifier:** `yarn test tests/format/<language>` (path filter keeps it under 30s; full suite is slow)

## 7. excalidraw/excalidraw

The virtual whiteboard. React + TypeScript, vitest, strict typecheck.

- **Why it loops:** UI bugs come with reproduction steps, and the repo enforces `tsc` clean plus a unit suite — a ready-made composite verifier.
- **Issues:** [good first issue](https://github.com/excalidraw/excalidraw/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22) (35 open at last check)
- **Setup:** `yarn`
- **Verifier:** `yarn test:typecheck && yarn test:app --watch=false`

## 8. astral-sh/ruff

The Python linter and formatter, written in Rust. `cargo` is the whole toolchain.

- **Why it loops:** every lint rule is snapshot-tested (insta). Rule bugs and new-rule requests reduce to: fixture in, snapshot out, loop until it matches.
- **Issues:** [help wanted](https://github.com/astral-sh/ruff/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22) (26 open at last check)
- **Setup:** `cargo build` (first build takes a few minutes; after that, fast)
- **Verifier:** `cargo test -p ruff_linter`

## 9. nushell/nushell

A shell where pipelines carry structured data instead of text.

- **Why it loops:** commands are small, self-contained, and individually tested. Command bugs have one-line reproductions you can paste straight into a test.
- **Issues:** [good first issue](https://github.com/nushell/nushell/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22) (12 open at last check)
- **Setup:** `cargo build` (first build takes a few minutes)
- **Verifier:** `cargo test -p nu-command`

## 10. microsoft/TypeScript

The compiler itself. Heavier than the rest — take it if you want the fight.

- **Why it loops:** thousands of baseline tests; a compiler bug is a `.ts` input plus expected diagnostics. Targeted test runs take seconds even though the full suite takes an hour.
- **Issues:** [good first issue](https://github.com/microsoft/TypeScript/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22) (12 open at last check; [Help Wanted](https://github.com/microsoft/TypeScript/issues?q=is%3Aissue+is%3Aopen+label%3A%22Help+Wanted%22) has ~900 more)
- **Setup:** `npm ci`
- **Verifier:** `npx hereby runtests --tests=<regex>`

---

Picked one? Go back to [README.md](README.md), write the loop, and make the verifier the exit condition — not your judgment.
