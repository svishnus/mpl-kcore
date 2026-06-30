# K Core Decomposition in MPL

Parallel *k*-core decomposition in MPL (MaPLe), implementing "Parallel *k*-Core
Decomposition: Theory and Practice" (Liu, Dong, Gu, Sun — PACMMOD/SIGMOD 2025).
See [PLAN.md](PLAN.md) for the detailed design and milestones.

## Build & run

```sh
smlpkg sync                      # fetch deps (mpllib, splittable random) into lib/
make                             # build ./kcore
./kcore @mpl procs 4 -- -input inputs/tiny.adj -algo seq --check --print
```

`make run PROCS=8 INPUT=… ALGO=…` is a convenience wrapper.

## Plan

- Include mpl lib and graph reading utils
- Fix proper graph data structure
- Get some reasonably large inputs
- Implement sequential baseline
- Implement offline - Julienne
- Implement online - with atomics
- Implement sampling - use shwestrick splittable-sml-random
- Implement VGC
- Check for parallel hash bag implementation
- Implement HBS
