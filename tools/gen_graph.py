#!/usr/bin/env python3
"""Generate symmetric graphs in PBBS adjacency (.adj) format for testing.

The PBBS adjacency format is:

    AdjacencyGraph
    <n>                  number of vertices
    <m>                  number of directed arcs (= 2 * undirected edges)
    <offset_0>           m entries: start of each vertex's adjacency list
    ...
    <offset_{n-1}>
    <arc_0>              m entries: concatenated, sorted adjacency lists
    ...
    <arc_{m-1}>

All generators emit undirected graphs (every edge appears in both endpoints'
lists) with no self-loops, as k-core requires.

Usage:
    gen_graph.py grid   ROWS COLS          > g.adj   (4-neighbour 2D grid)
    gen_graph.py clique N                  > g.adj   (coreness n-1 everywhere)
    gen_graph.py star   N                  > g.adj   (coreness 1 everywhere)
    gen_graph.py random N M [SEED]         > g.adj   (Erdos-Renyi, M edges)
    gen_graph.py powerlaw N M [SEED]       > g.adj   (Barabasi-Albert-ish)
"""
import sys
import random


def emit(n, adj, out=sys.stdout):
    """adj: list of neighbour-sets (or sorted lists). Writes .adj format."""
    lists = [sorted(adj[v]) for v in range(n)]
    m = sum(len(l) for l in lists)
    w = out.write
    w("AdjacencyGraph\n")
    w(f"{n}\n")
    w(f"{m}\n")
    off = 0
    for v in range(n):
        w(f"{off}\n")
        off += len(lists[v])
    for v in range(n):
        for u in lists[v]:
            w(f"{u}\n")


def add_edge(adj, u, v):
    if u != v:
        adj[u].add(v)
        adj[v].add(u)


def gen_grid(rows, cols):
    n = rows * cols
    adj = [set() for _ in range(n)]
    for r in range(rows):
        for c in range(cols):
            v = r * cols + c
            if c + 1 < cols:
                add_edge(adj, v, v + 1)
            if r + 1 < rows:
                add_edge(adj, v, v + cols)
    return n, adj


def gen_clique(n):
    adj = [set(range(n)) - {v} for v in range(n)]
    return n, adj


def gen_star(n):
    adj = [set() for _ in range(n)]
    for v in range(1, n):
        add_edge(adj, 0, v)
    return n, adj


def gen_random(n, m, seed=0):
    rng = random.Random(seed)
    adj = [set() for _ in range(n)]
    added = 0
    while added < m:
        u = rng.randrange(n)
        v = rng.randrange(n)
        if u != v and v not in adj[u]:
            add_edge(adj, u, v)
            added += 1
    return n, adj


def gen_powerlaw(n, m, seed=0):
    """Preferential attachment: each new vertex links to existing vertices
    chosen proportionally to current degree, producing a few high-degree hubs."""
    rng = random.Random(seed)
    adj = [set() for _ in range(n)]
    targets = []  # multiset of vertices, weighted by degree
    deg_per_new = max(1, m // max(1, n))
    # seed with a small clique
    seed_size = min(n, deg_per_new + 1)
    for u in range(seed_size):
        for v in range(u + 1, seed_size):
            add_edge(adj, u, v)
            targets += [u, v]
    for v in range(seed_size, n):
        chosen = set()
        while len(chosen) < min(deg_per_new, v):
            u = targets[rng.randrange(len(targets))] if targets else rng.randrange(v)
            if u != v:
                chosen.add(u)
        for u in chosen:
            add_edge(adj, v, u)
            targets += [u, v]
    return n, adj


def main(argv):
    if len(argv) < 2:
        sys.stderr.write(__doc__)
        return 1
    kind = argv[1]
    if kind == "grid":
        n, adj = gen_grid(int(argv[2]), int(argv[3]))
    elif kind == "clique":
        n, adj = gen_clique(int(argv[2]))
    elif kind == "star":
        n, adj = gen_star(int(argv[2]))
    elif kind == "random":
        n, adj = gen_random(int(argv[2]), int(argv[3]),
                            int(argv[4]) if len(argv) > 4 else 0)
    elif kind == "powerlaw":
        n, adj = gen_powerlaw(int(argv[2]), int(argv[3]),
                              int(argv[4]) if len(argv) > 4 else 0)
    else:
        sys.stderr.write(f"unknown graph kind: {kind}\n")
        return 1
    emit(n, adj)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
