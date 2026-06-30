# Parallel k-Core Decomposition in MPL — Implementation Plan

Implementing "Parallel *k*-Core Decomposition: Theory and Practice" (Liu, Dong, Gu,
Sun — PACMMOD/SIGMOD 2025, Article 195; `paper.pdf`) in MPL (MaPLe parallel SML).
Reference C++ artifact: <https://github.com/ucrparlay/Parallel-KCore>.

## Goal

Compute the **coreness** κ(v) for every vertex v (κ(v) = max k such that v is in the
k-core), in O(n + m) work with high parallelism, matching the paper's framework and
its three optimizations (sampling, VGC, HBS).

## Environment (decided)

- **Compiler:** MPL, switching to **mainline `HEAD`** (`ca92f648`, Apr 2026) via
  `mpl-switch` — plain mainline, no hybrid GPU scheduler. Machine is ARM64 (aarch64,
  likely Grace-Hopper).
- **Dependencies:** managed with **`smlpkg`** (`sml.pkg` manifest). Pull
  `github.com/MPLLang/mpllib` (graphs, sequences, `SeqBasis`, hashtables, parallel
  file I/O, `CommandLineArgs`) and `github.com/shwestrick/splittable-sml-random`
  (parallel RNG for the sampling scheme).
- **Primitives:** `ForkJoin.{par,parfor,alloc}`; atomics via
  `MLton.Parallel.{fetchAndAdd,arrayFetchAndAdd,compareAndSwap,arrayCompareAndSwap}`.
- **GOTCHA:** confirm default int width after the switch. On the prior build
  `Int.maxInt = 2^31−1` (32-bit). For billion-edge graphs, edge offsets/counts must
  be 64-bit (`Int64`/`Word64`); vertex ids can stay 32-bit.

## Repository layout (target)

```
mpl-kcore/
  sml.pkg                  smlpkg manifest
  lib/github.com/...        fetched dependencies (smlpkg)
  Makefile                  build targets per binary
  src/
    KCoreCommon.sml         shared types, induced-degree array, frontier reps
    SeqKCore.sml            sequential O(n+m) peeling baseline
    OnlineKCore.sml         Alg 1 framework + Alg 3 online/atomic Peel
    Sampling.sml            Alg 4/5 sampler struct + SetSampler/Validate/Resample
    VGC.sml                 per-vertex local FIFO queue local search
    HBS.sml                 hierarchical bucketing structure (hash-bag buckets)
    HashBag.sml             parallel hash bag (BagInsert / BagExtractAll)
    Checker.sml             verify coreness against sequential result
    Main.sml                CLI: pick algorithm, read graph, time, report
  inputs/                   small test graphs + scripts to fetch/generate big ones
  test/                     unit/correctness drivers
```

## Milestones (each ends in a signed git commit)

1. **Toolchain + scaffold.** Switch MPL, build smlpkg, write `sml.pkg`, fetch deps,
   minimal `Main` that reads a graph and prints n/m. Re-verify int width.
2. **Graph I/O + inputs.** Use mpllib `AdjacencyGraph` (PBBS adjacency format,
   text + binary). Symmetrize directed inputs. Grab a few small real graphs and a
   generator (grid, power-law) for adversarial cases.
3. **Sequential baseline + checker.** Bucket-sort peeling (Matula–Beck/BZ), O(n+m).
   `Checker` compares any parallel result to this.
4. **Online/atomic framework (Alg 1 + Alg 3).** `active set 𝒜`, per-round frontier
   𝓕 = {v : d̃[v]=k}, parallel Peel with `arrayFetchAndAdd` decrements, next frontier
   collected in a **parallel hash bag**. This is the correct, fast baseline parallel
   algorithm. Validate with checker; measure self-relative speedup.
5. **Sampling (Alg 4/5).** Per-vertex `sampler{mode,rate,cnt}`; high-degree vertices
   enter sample mode and `atomic_inc` a sample counter with probability `rate` instead
   of decrementing every edge; `Validate`/`Resample` with the paper's parameters
   (r=0.1, μ=4c·ln n). Cuts contention on dense graphs.
6. **VGC.** When peeling a low-degree v, push neighbors that drop to k into a local
   FIFO queue (cap ~128) and process them in the same subround — fewer global
   synchronizations on sparse graphs.
7. **HBS.** Exponentially-growing buckets (degree ranges 1,1,1,…,then 2,4,8,…) backed
   by hash bags; `BuildBuckets`/`GetNextBucket`/`DecreaseKey`. Switch on only when a
   θ-core (θ=16) is reached. Improves active-set maintenance on dense graphs.
8. **Benchmark + validate.** Harness over several graphs; confirm correctness and
   measure speedup vs sequential and across core counts.

## Correctness strategy

Every parallel variant is checked against the sequential baseline on every test graph
in CI-style runs before its milestone commit. Adversarial inputs (high-coreness HCNS,
power-law HPL, sqrt(n)-subround GRID) are included to stress sampling/VGC/HBS.

## Open questions deferred to implementation

- Exact frontier representation (hash bag vs mpllib `VertexSubset` SPARSE/DENSE) — will
  benchmark both for the online framework.
- Whether to keep coreness/degree arrays as `Int32` for cache footprint with a separate
  64-bit edge-offset array.
