#!/usr/bin/env python3
"""frontier.py — compute the ready frontier of an HTML task-hypergraph.

Usage:
  frontier.py TOPOLOGY.html [--shard N]

Status is read straight from each node's data-status (topology.html is the
single source of truth — no separate status file). A node is READY when every
dependency is `done` and its own status is actionable (todo | doing | gate_fail).

Output is plain text (no JSON):
  ready: <ids whose deps are all done and own status actionable>
  clusters: <group> | <group> | ...   (ready ids sharing no file & no hyperedge)
  isolate: <ready ids whose files overlap another ready id — worktree-isolate>
  blocked: <id(needs: dep dep)> ...   (not done/killed, >=1 unmet dep)
  done: <done_count>/<total>

With --shard N, also prints the ready set pre-chunked for fan-out — launch ONE
Workflow per shard line, concurrently, to exceed a single Workflow's agent cap:
  shards: <count>
  shard: <=N ready ids                (one line per shard / Workflow invocation)
Any ready node that shares a file with another ready node is in `isolate`, so
its DO-agent worktree-isolates — making cross-shard file overlap safe.

Exit 0 normally (all-done => ready empty). Exit 3 on deadlock (nothing ready,
not all done, nothing in progress). Exit 2 on bad usage / unreadable file.
"""

import sys
from html.parser import HTMLParser

PROG = "frontier.py"
DONE = "done"
ACTIONABLE = {"todo", "doing", "gate_fail"}
TERMINAL = {"done", "killed"}
INPROGRESS = {"doing"}


def _ids(v):
    return [t for t in (v or "").split() if t]


class GraphParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.nodes = {}   # id -> {status, deps, files}
        self.order = []
        self.edges = []   # hyperedges: list of member-id sets

    def handle_starttag(self, tag, attrs):
        a = {k: (v or "") for k, v in attrs}
        classes = a.get("class", "").split()
        if "node" in classes:
            nid = a.get("id", "").strip()
            if not nid:
                return
            self.nodes[nid] = {
                "status": (a.get("data-status") or "todo").strip().lower(),
                "deps": _ids(a.get("data-deps")),
                "files": set(_ids(a.get("data-files"))),
            }
            if nid not in self.order:
                self.order.append(nid)
        elif "hyperedge" in classes:
            self.edges.append(set(_ids(a.get("data-members"))))


def main(argv):
    rest = argv[1:]
    if any(a in ("-h", "--help") for a in rest):
        print(__doc__)
        return 0

    def usage_err(msg):
        sys.stderr.write(f"{PROG}: error: {msg}\n")
        sys.stderr.write("usage: frontier.py TOPOLOGY.html [--shard N]\n")
        return 2

    path = None
    shard_size = None
    i = 0
    while i < len(rest):
        a = rest[i]
        if a == "--shard":
            if i + 1 >= len(rest):
                return usage_err("--shard requires an integer N")
            val = rest[i + 1]
            i += 2
        elif a.startswith("--shard="):
            val = a.split("=", 1)[1]
            i += 1
        elif a.startswith("-"):
            return usage_err(f"unknown option '{a}'")
        elif path is None:
            path = a
            i += 1
            continue
        else:
            return usage_err("expected exactly one TOPOLOGY.html")
        # fell through from a --shard form: validate the integer
        try:
            shard_size = int(val)
        except (TypeError, ValueError):
            return usage_err(f"--shard expects an integer, got '{val}'")
        if shard_size < 1:
            return usage_err("--shard N must be >= 1")
    if path is None:
        return usage_err("expected exactly one TOPOLOGY.html")

    try:
        with open(path, "r", encoding="utf-8") as fh:
            html = fh.read()
    except OSError as e:
        sys.stderr.write(f"{PROG}: error: cannot read {path}: {e}\n")
        return 2

    p = GraphParser()
    p.feed(html)
    nodes, order, edges = p.nodes, p.order, p.edges
    total = len(order)
    done_count = sum(1 for n in order if nodes[n]["status"] == DONE)

    def deps_met(nid):
        return all(nodes.get(d, {}).get("status") == DONE for d in nodes[nid]["deps"])

    ready = [n for n in order if nodes[n]["status"] in ACTIONABLE and deps_met(n)]

    # Blocked: non-terminal nodes with >=1 unmet dependency.
    blocked = []
    for n in order:
        if nodes[n]["status"] in TERMINAL:
            continue
        unmet = [d for d in nodes[n]["deps"] if nodes.get(d, {}).get("status") != DONE]
        if unmet:
            blocked.append((n, unmet))

    # File-overlap -> isolate (worktree-isolate shared-file writers).
    isolate = []
    for a in ready:
        fa = nodes[a]["files"]
        if any(a != b and fa & nodes[b]["files"] for b in ready):
            isolate.append(a)

    # Clusters: greedy first-fit; members of a cluster share no file & no hyperedge.
    def shares_edge(a, b):
        return any(a in e and b in e for e in edges)

    clusters = []
    for n in ready:
        placed = False
        for cl in clusters:
            if all(not (nodes[n]["files"] & nodes[m]["files"]) and not shares_edge(n, m)
                   for m in cl):
                cl.append(n)
                placed = True
                break
        if not placed:
            clusters.append([n])

    print("ready: " + (" ".join(ready) if ready else "(none)"))
    print("clusters: " + (" | ".join(" ".join(c) for c in clusters) if clusters else "(none)"))
    print("isolate: " + (" ".join(isolate) if isolate else "(none)"))
    print("blocked: " + (" ".join(f"{n}(needs: {' '.join(u)})" for n, u in blocked)
                         if blocked else "(none)"))
    print(f"done: {done_count}/{total}")

    # --shard N: pre-chunk the ready set into fan-out shards (<=N each), one line
    # per shard. The orchestrator launches one Workflow per shard, concurrently.
    if shard_size is not None:
        shards = [ready[i:i + shard_size] for i in range(0, len(ready), shard_size)]
        print(f"shards: {len(shards)}")
        for sh in shards:
            print("shard: " + " ".join(sh))

    if not ready and done_count < total and not any(
            nodes[n]["status"] in INPROGRESS for n in order):
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
