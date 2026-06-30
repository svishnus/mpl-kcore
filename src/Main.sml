(* Main.sml --- command-line driver for k-core decomposition.
 *
 * Usage:
 *   ./kcore @mpl procs <P> -- -input <graph.adj> [-algo seq] [--check]
 *
 *   -input   path to a PBBS-format adjacency graph (required)
 *   -algo    which algorithm to run (default: seq)
 *   --check  validate the result against the sequential baseline
 *   --print  print the coreness of every vertex (for small graphs)
 *)

structure Main =
struct
  val input = CommandLineArgs.parseString "input" ""
  val algo = CommandLineArgs.parseString "algo" "seq"
  val doCheck = CommandLineArgs.parseFlag "check"
  val doPrint = CommandLineArgs.parseFlag "print"

  val () = if input <> "" then () else Util.die "missing -input <graph.adj>"

  val () = print ("input " ^ input ^ "\n")
  val (g, loadTime) = Util.getTime (fn () => Graph.fromFile input)
  val () = print ("vertices " ^ Int.toString (Graph.numVertices g) ^ "\n")
  val () = print ("arcs " ^ Int.toString (Graph.numArcs g) ^ "\n")
  val () = print ("load_time " ^ Time.fmt 4 loadTime ^ "s\n")

  fun run name =
    case name of
      "seq" => SeqKCore.coreness g
    | "online" => OnlineKCore.coreness g
    | other => Util.die ("unknown -algo: " ^ other)

  val (core, runTime) = Util.getTime (fn () => run algo)
  val kmax = Array.foldl Int.max 0 core
  val () = print ("algo " ^ algo ^ "\n")
  val () = print ("time " ^ Time.fmt 4 runTime ^ "s\n")
  val () = print ("kmax " ^ Int.toString kmax ^ "\n")

  val () =
    if not doPrint then ()
    else Util.for (0, Graph.numVertices g) (fn v =>
      print ("coreness[" ^ Int.toString v ^ "] = "
             ^ Int.toString (Array.sub (core, v)) ^ "\n"))

  val () =
    if not doCheck then ()
    else ignore (Checker.report (SeqKCore.coreness g, core))
end
