#!/usr/bin/env python3
"""validate.py — acyclicity + reference check for an HTML task-hypergraph.

Usage:
  validate.py TOPOLOGY.html

Parses the authoritative <article class="node"> / <div class="hyperedge">
elements (and their data-* attributes) with the stdlib HTML parser, then:
  - flags DANGLING references (data-deps / data-blocks / data-members pointing
    at an undefined node id),
  - detects CYCLES via Kahn's algorithm.

Output is plain text (no JSON):
  success -> stdout:
      OK
      build_order: <topo-sorted ids>
      waves: <wave0 ids> | <wave1 ids> | ...
    exit 0
  invalid -> stdout:
      FAIL
      error: <message>
      ...
    exit 1
  bad usage / unreadable file -> stderr, exit 2
"""

import sys
from html.parser import HTMLParser

PROG = "validate.py"


def _ids(v):
    return [t for t in (v or "").split() if t]


class GraphParser(HTMLParser):
    """Collect node + hyperedge elements and their data-* attributes."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.nodes = {}   # id -> {deps, blocks}
        self.order = []   # node ids in document order
        self.hyperedges = []  # {id, members, deps, blocks}

    def handle_starttag(self, tag, attrs):
        a = {k: (v or "") for k, v in attrs}
        classes = a.get("class", "").split()
        if "node" in classes:
            nid = a.get("id", "").strip()
            if not nid:
                return
            self.nodes[nid] = {
                "deps": _ids(a.get("data-deps")),
                "blocks": _ids(a.get("data-blocks")),
            }
            if nid not in self.order:
                self.order.append(nid)
        elif "hyperedge" in classes:
            self.hyperedges.append({
                "id": a.get("data-id", a.get("id", "")).strip(),
                "members": _ids(a.get("data-members")),
                "deps": _ids(a.get("data-deps")),
                "blocks": _ids(a.get("data-blocks")),
            })


def main(argv):
    args = [x for x in argv[1:] if x not in ("-h", "--help")]
    if len(argv) > 1 and argv[1] in ("-h", "--help"):
        print(__doc__)
        return 0
    if len(args) != 1:
        sys.stderr.write(f"{PROG}: error: expected exactly one TOPOLOGY.html\n")
        sys.stderr.write("usage: validate.py TOPOLOGY.html\n")
        return 2
    path = args[0]
    try:
        with open(path, "r", encoding="utf-8") as fh:
            html = fh.read()
    except OSError as e:
        sys.stderr.write(f"{PROG}: error: cannot read {path}: {e}\n")
        return 2

    p = GraphParser()
    p.feed(html)
    nodes, order = p.nodes, p.order

    errors = []
    defined = set(nodes)

    # Dangling references.
    for nid in order:
        for d in nodes[nid]["deps"]:
            if d not in defined:
                errors.append(f'node "{nid}" depends on undefined node: {d}')
        for b in nodes[nid]["blocks"]:
            if b not in defined:
                errors.append(f'node "{nid}" blocks undefined node: {b}')
    for he in p.hyperedges:
        for m in he["members"] + he["deps"] + he["blocks"]:
            if m not in defined:
                tag = he["id"] or "(unnamed)"
                errors.append(f'hyperedge "{tag}" references undefined node: {m}')

    # Kahn layered topo sort over real edges (dep -> node), defined nodes only.
    indeg = {nid: 0 for nid in order}
    adj = {nid: [] for nid in order}
    for nid in order:
        for d in nodes[nid]["deps"]:
            if d in defined:
                adj[d].append(nid)
                indeg[nid] += 1
    waves, placed = [], 0
    frontier = sorted([n for n in order if indeg[n] == 0])
    while frontier:
        waves.append(frontier)
        placed += len(frontier)
        nxt = []
        for n in frontier:
            for m in adj[n]:
                indeg[m] -= 1
                if indeg[m] == 0:
                    nxt.append(m)
        frontier = sorted(nxt)
    if placed != len(order):
        stuck = sorted(n for n in order if indeg[n] > 0)
        errors.append(f"cycle among: {', '.join(stuck)}")

    if errors:
        print("FAIL")
        for e in errors:
            print(f"error: {e}")
        return 1

    build_order = [n for wave in waves for n in wave]
    print("OK")
    print("build_order: " + " ".join(build_order))
    print("waves: " + " | ".join(" ".join(w) for w in waves))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
