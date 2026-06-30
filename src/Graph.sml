(* Graph.sml --- undirected graph for k-core decomposition.
 *
 * A thin, purpose-built facade over mpllib's AdjacencyGraph (compressed
 * sparse row).  k-core is defined on undirected graphs, so we assume the
 * input is symmetric: every edge {u,v} appears in both u's and v's adjacency
 * list.  PBBS-format `.adj` files and the standard benchmark graphs satisfy
 * this; `checkSymmetric` is provided to validate untrusted inputs. *)

signature GRAPH =
sig
  type graph
  type vertex = int

  (* Read a graph in PBBS adjacency format (text `.adj` or binary `.bin`). *)
  val fromFile : string -> graph

  val numVertices : graph -> int
  (* Number of directed arcs = total length of all adjacency lists.  For a
   * symmetric graph this is twice the number of undirected edges. *)
  val numArcs : graph -> int

  val degree : graph -> vertex -> int
  val neighbors : graph -> vertex -> vertex Seq.t

  (* Apply f to each neighbor of v, in order. *)
  val appNeighbors : graph -> vertex -> (vertex -> unit) -> unit

  (* Verify the adjacency lists are symmetric and self-loop free.  Linear
   * work; used only when an input's provenance is unknown. *)
  val checkSymmetric : graph -> bool
end

structure Graph :> GRAPH =
struct
  structure G = AdjacencyGraph(Int)

  type graph = G.graph
  type vertex = int

  val fromFile = G.parseFile
  val numVertices = G.numVertices
  val numArcs = G.numEdges
  val degree = G.degree
  val neighbors = G.neighbors

  fun appNeighbors g v f =
    let
      val nbrs = G.neighbors g v
      val d = Seq.length nbrs
      fun loop i = if i >= d then () else (f (Seq.nth nbrs i); loop (i + 1))
    in
      loop 0
    end

  fun checkSymmetric g =
    let
      val n = numVertices g
      (* v has an arc to u iff u has an arc to v, and v has no self-loop. *)
      fun arcExists (u, v) =
        let val nbrs = neighbors g u
        in Seq.iterate (fn (b, w) => b orelse w = v) false nbrs
        end
      fun okVertex v =
        Seq.iterate
          (fn (b, u) => b andalso u <> v andalso arcExists (u, v))
          true (neighbors g v)
    in
      (* Sequential and quadratic in degree; intended only for small inputs. *)
      List.all okVertex (List.tabulate (n, fn v => v))
    end
end
