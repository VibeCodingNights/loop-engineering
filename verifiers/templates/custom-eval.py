#!/usr/bin/env python3
"""custom-eval.py — blank verifier template. Copy it, rename it, fill in checks.

The four rules. Every verifier must:
  1. Be a command that exits 0 (pass) or non-zero (fail).
  2. Run in under 30 seconds.
  3. Require no human judgment.
  4. Test the actual outcome, not the process.

Make the subjective mechanical. "Documentation covers all public APIs"
sounds like a judgment call. It is not: parse the AST, list every exported
function, check each one has a JSDoc block. Zero missing = pass. Most
"subjective" goals hide a mechanical check like that. Find it, write it here.

Convention: a check is a function taking the target dir and returning
(passed, message). Add yours to CHECKS. The runner prints one line per
check and exits 0 only if all pass.

Runs as-is so you can see the output shape immediately:
    python3 verifiers/templates/custom-eval.py --target .

Loop hookup:
    until python3 verifiers/templates/custom-eval.py --target .; do
        claude -p "…your goal… Verifier: python3 verifiers/templates/custom-eval.py --target ."
    done
"""

import argparse
import sys
from pathlib import Path

# ── CHECKS ── EDIT ME: replace the examples with your own ────────────────


def check_target_exists(target: Path) -> tuple[bool, str]:
    """Trivial example so the template runs out of the box."""
    if target.is_dir():
        return True, f"{target} is a directory"
    return False, f"{target} does not exist or is not a directory"


def check_no_todo_markers(target: Path) -> tuple[bool, str]:
    """Example of making 'the work is finished' mechanical: zero TODOs."""
    hits = []
    for ext in ("*.py", "*.js", "*.ts"):
        for f in target.rglob(ext):
            if ".git" in f.parts or "node_modules" in f.parts:
                continue
            try:
                lines = f.read_text(errors="ignore").splitlines()
            except OSError:
                continue
            for i, line in enumerate(lines, 1):
                if "TODO" in line:
                    hits.append(f"{f}:{i}")
    if hits:
        return False, f"{len(hits)} TODO markers remain, first: {hits[0]}"
    return True, "zero TODO markers"


CHECKS = [
    check_target_exists,
    check_no_todo_markers,
]

# ─────────────────────────────────────────────────────────────────────────


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Custom verifier: exits 0 only if every check passes."
    )
    parser.add_argument("--target", default=".", help="directory to verify (default: .)")
    args = parser.parse_args()
    target = Path(args.target)

    results = []
    for check in CHECKS:
        try:
            passed, message = check(target)
        except Exception as exc:  # a crashing check is a failing check
            passed, message = False, f"check raised {type(exc).__name__}: {exc}"
        results.append(passed)
        print(f"{'PASS' if passed else 'FAIL'}  {check.__name__}  — {message}")

    if all(results):
        print(f"PASS: {len(results)}/{len(results)} checks green")
        return 0
    print(f"FAIL: {results.count(False)}/{len(results)} checks failed")
    return 1


if __name__ == "__main__":
    sys.exit(main())
