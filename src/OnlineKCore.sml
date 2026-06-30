(* OnlineKCore.sml --- work-efficient parallel k-core (online / atomic).
 *
 * This is the paper's framework (Algorithm 1) with the online peeling process
 * (Algorithm 3): degrees of a peeled vertex's neighbours are decremented
 * directly with atomic fetch-and-add, and a neighbour joins the next frontier
 * exactly when its induced degree transitions from k+1 to k.
 *
 *   d~[v]  induced degree of v, atomically decremented as neighbours peel
 *   A      active set: vertices not yet peeled (induced degree > k)
 *   F      frontier: active vertices whose induced degree has reached k
 *
 * The framework is work-efficient: each vertex appears in exactly one frontier
 * and each arc is relaxed exactly once, for O(n + m) total work.  The next
 * frontier is gathered by atomically appending to a preallocated buffer; this
 * single counter is a contention point on dense graphs, which the sampling and
 * hash-bag techniques (later milestones) address. *)

structure OnlineKCore :> KCORE =
struct
  structure P = MLton.Parallel

  (* parfor block size; the inner neighbour scan of each frontier vertex is
   * sequential, so a small grain keeps frontier work well distributed. *)
  val grain = 256

  fun coreness (g : Graph.graph) : int array =
    let
      val n = Graph.numVertices g
      val core = Array.array (n, 0)
    in
      if n = 0 then core
      else
        let
          (* Induced degrees, decremented atomically during peeling. *)
          val d : int array = SeqBasis.tabulate 10000 (0, n) (Graph.degree g)

          (* Scratch buffer + counter for accumulating the next frontier. *)
          val nextBuf : int array = ForkJoin.alloc n
          val nextCount = ref 0

          (* Peel frontier `fr` (length `flen`) at level k; set coreness of its
           * vertices and return the next frontier as a fresh array. *)
          fun peel (fr : int array, flen : int, k : int) : int array =
            let
              val () = nextCount := 0
              val () =
                ForkJoin.parfor grain (0, flen) (fn i =>
                  let val v = Array.sub (fr, i) in
                    Array.update (core, v, k);
                    Graph.appNeighbors g v (fn u =>
                      let val old = P.arrayFetchAndAdd (d, u) (~1) in
                        (* u just dropped from k+1 to k: it is newly peeled. *)
                        if old = k + 1 then
                          Array.update (nextBuf, P.fetchAndAdd nextCount 1, u)
                        else ()
                      end)
                  end)
            in
              SeqBasis.tabulate grain (0, !nextCount) (fn i => Array.sub (nextBuf, i))
            end

          (* Run all subrounds of round k until the frontier drains. *)
          fun runRound (fr, flen, k) =
            if flen = 0 then ()
            else
              let val next = peel (fr, flen, k)
              in runRound (next, Array.length next, k) end

          (* `keep p` packs the active vertices satisfying predicate p on d~. *)
          fun keep (active, alen) p =
            SeqBasis.filter grain (0, alen)
              (fn i => Array.sub (active, i))
              (fn i => p (Array.sub (d, Array.sub (active, i))))

          (* Main loop over rounds. Invariant: every vertex in `active` has
           * induced degree >= k. *)
          fun loop (active, alen, k) =
            if alen = 0 then ()
            else
              let
                val fr = keep (active, alen) (fn dv => dv = k)
                val () = runRound (fr, Array.length fr, k)
                val active' = keep (active, alen) (fn dv => dv > k)
              in
                loop (active', Array.length active', k + 1)
              end

          val active0 = SeqBasis.tabulate 10000 (0, n) (fn v => v)
        in
          loop (active0, n, 0);
          core
        end
    end
end
