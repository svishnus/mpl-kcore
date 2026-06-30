(* KCORE.sml --- common interface for k-core decomposition algorithms.
 *
 * Every implementation (sequential baseline, online/atomic, and the optimized
 * variants) computes the coreness of each vertex: coreness[v] is the largest k
 * such that v belongs to the k-core. *)

signature KCORE =
sig
  val coreness : Graph.graph -> int array
end
