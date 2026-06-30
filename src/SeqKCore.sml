(* SeqKCore.sml --- sequential O(n+m) k-core decomposition.
 *
 * The classic bin-sort peeling algorithm of Batagelj and Zaversnik (2003).
 * Vertices are kept in `vert`, ordered by current induced degree, with `bin`
 * marking the start of each degree class and `pos` giving each vertex's slot.
 * Peeling a vertex in nondecreasing degree order yields its coreness; when a
 * neighbour's degree drops it is swapped to the front of its class in O(1).
 *
 * This is the ground-truth baseline against which every parallel variant is
 * checked. *)

structure SeqKCore =
struct
  (* Imperative loop over the half-open range [lo, hi). *)
  fun for (lo, hi) (f : int -> unit) =
    let fun go i = if i >= hi then () else (f i; go (i + 1))
    in go lo end

  fun coreness (g : Graph.graph) : int array =
    let
      val n = Graph.numVertices g
      val core = Array.array (n, 0)
    in
      if n = 0 then core
      else
        let
          (* Mutable induced degrees, decremented as neighbours are peeled. *)
          val deg = Array.tabulate (n, Graph.degree g)
          val maxDeg = Array.foldl Int.max 0 deg

          (* bin[d] will become the start index of the degree-d class. *)
          val bin = Array.array (maxDeg + 1, 0)
          val () = Array.app (fn d => Array.update (bin, d, Array.sub (bin, d) + 1)) deg

          (* Exclusive prefix-sum of the counts: bin[d] := sum of counts < d. *)
          val () =
            let
              fun go (d, acc) =
                if d > maxDeg then ()
                else
                  let val cnt = Array.sub (bin, d)
                  in Array.update (bin, d, acc); go (d + 1, acc + cnt) end
            in go (0, 0) end

          (* Place vertices into `vert` ordered by degree, recording `pos`.
           * `bin` is advanced as a cursor, then shifted back afterwards. *)
          val vert = Array.array (n, 0)
          val pos = Array.array (n, 0)
          val () =
            for (0, n) (fn v =>
              let val d = Array.sub (deg, v)
                  val p = Array.sub (bin, d)
              in Array.update (pos, v, p);
                 Array.update (vert, p, v);
                 Array.update (bin, d, p + 1)
              end)
          val () =
            let fun go d = if d <= 0 then ()
                           else (Array.update (bin, d, Array.sub (bin, d - 1)); go (d - 1))
            in go maxDeg end
          val () = Array.update (bin, 0, 0)

          (* Peel in nondecreasing degree order. *)
          val () =
            for (0, n) (fn i =>
              let
                val v = Array.sub (vert, i)
                val dv = Array.sub (deg, v)
                val () = Array.update (core, v, dv)
              in
                Graph.appNeighbors g v (fn u =>
                  let val du = Array.sub (deg, u) in
                    if du <= dv then ()
                    else
                      let
                        val pu = Array.sub (pos, u)
                        val pw = Array.sub (bin, du)
                        val w = Array.sub (vert, pw)
                      in
                        (* Move u to the front of its degree class. *)
                        if u <> w then
                          (Array.update (vert, pu, w);
                           Array.update (vert, pw, u);
                           Array.update (pos, w, pu);
                           Array.update (pos, u, pw))
                        else ();
                        Array.update (bin, du, pw + 1);
                        Array.update (deg, u, du - 1)
                      end
                  end)
              end)
        in
          core
        end
    end
end
