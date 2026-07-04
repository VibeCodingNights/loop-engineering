#!/usr/bin/env python3
"""api-conformance.py — verifier: every endpoint answers with a declared status.

Contract: exits 0 = pass, non-zero = fail. Under 30 seconds — TIMEOUT is
per request, so keep the spec small or raise your budget. No human
judgment. Tests the outcome (the running API), not the process.

Reads an OpenAPI 3.x spec, hits every path/method against BASE_URL, and
compares the status code to what the spec declares. JSON specs always
work (stdlib). YAML works only if pyyaml happens to be installed —
otherwise convert your spec to JSON first.

Adapt: edit the CONFIG block. All values can also be overridden by env
vars of the same name.

Loop hookup:
    until python3 verifiers/templates/api-conformance.py; do
        claude -p "Make every endpoint match openapi.json. Verifier: python3 verifiers/templates/api-conformance.py"
    done
"""

import json
import os
import sys
import urllib.error
import urllib.request

# ── CONFIG ── EDIT ME ────────────────────────────────────────────────────
SPEC_PATH = os.environ.get("SPEC_PATH", "openapi.json")
BASE_URL = os.environ.get("BASE_URL", "http://localhost:3000")
TIMEOUT = float(os.environ.get("TIMEOUT", "5"))  # seconds per request
EXPECT = os.environ.get("EXPECT", "declared")
#   "declared" — status must appear in the spec's responses for that operation
#   "2xx"      — status must be 2xx, spec responses ignored (happy-path mode)
PATH_PARAMS = {"id": "1"}  # values for {placeholders}; anything unlisted becomes "1"
SKIP_METHODS = set()       # e.g. {"delete"} to leave destructive routes alone
# ─────────────────────────────────────────────────────────────────────────

HTTP_METHODS = {"get", "put", "post", "delete", "options", "head", "patch", "trace"}


def load_spec(path):
    try:
        text = open(path, encoding="utf-8").read()
    except OSError as exc:
        sys.exit(f"FAIL: cannot read spec {path}: {exc}")
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        try:
            import yaml  # type: ignore
        except ImportError:
            sys.exit(f"FAIL: {path} is not JSON and pyyaml is not installed — convert the spec to JSON")
        return yaml.safe_load(text)


def fill_path(path):
    out = path
    while "{" in out and "}" in out:
        key = out[out.index("{") + 1 : out.index("}")]
        out = out.replace("{" + key + "}", str(PATH_PARAMS.get(key, "1")), 1)
    return out


def hit(method, url):
    """Returns (status_code, error_string). Exactly one is None."""
    data = b"{}" if method in ("post", "put", "patch") else None
    req = urllib.request.Request(url, data=data, method=method.upper())
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            return resp.status, None
    except urllib.error.HTTPError as exc:
        return exc.code, None  # 4xx/5xx still carry a status code
    except Exception as exc:   # connection refused, timeout, DNS
        return None, str(getattr(exc, "reason", exc))


def acceptable(status, declared):
    if EXPECT == "2xx":
        return 200 <= status <= 299
    keys = {str(k).lower() for k in declared}
    return str(status) in keys or f"{status // 100}xx" in keys or "default" in keys


def main():
    spec = load_spec(SPEC_PATH)
    paths = spec.get("paths") or {}
    if not paths:
        sys.exit(f"FAIL: no paths found in {SPEC_PATH}")

    rows, failures = [], 0
    for path, ops in sorted(paths.items()):
        for method, op in (ops or {}).items():
            method = method.lower()
            if method not in HTTP_METHODS or method in SKIP_METHODS:
                continue
            declared = (op or {}).get("responses") or {}
            url = BASE_URL.rstrip("/") + fill_path(path)
            status, err = hit(method, url)
            if status is None:
                ok, got = False, f"ERR {err}"
            else:
                ok, got = acceptable(status, declared), str(status)
            want = "2xx" if EXPECT == "2xx" else ",".join(sorted(str(k) for k in declared)) or "any"
            if not ok:
                failures += 1
            rows.append((method.upper(), path, got, want, "ok" if ok else "FAIL"))

    if not rows:
        sys.exit("FAIL: spec has paths but no testable operations (check SKIP_METHODS)")

    headers = ("METHOD", "PATH", "GOT", "WANT")
    widths = [max(len(h), max(len(r[i]) for r in rows)) for i, h in enumerate(headers)]
    print("  ".join(h.ljust(w) for h, w in zip(headers, widths)) + "  RESULT")
    for row in rows:
        print("  ".join(c.ljust(w) for c, w in zip(row[:4], widths)) + f"  {row[4]}")

    if failures:
        print(f"FAIL: {failures}/{len(rows)} endpoints off-spec")
        sys.exit(1)
    print(f"PASS: {len(rows)}/{len(rows)} endpoints conform")
    sys.exit(0)


if __name__ == "__main__":
    main()
