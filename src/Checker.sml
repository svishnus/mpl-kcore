(* Checker.sml --- compare a computed coreness array against a reference.
 *
 * Every parallel variant is validated against the sequential baseline on the
 * input graph before its results are trusted. *)

structure Checker =
struct
  (* The first index at which the two arrays disagree, if any. *)
  fun firstMismatch (reference : int array, got : int array)
        : {vertex : int, expected : int, actual : int} option =
    let
      val n = Array.length reference
      fun loop i =
        if i >= n then NONE
        else
          let val e = Array.sub (reference, i)
              val a = Array.sub (got, i)
          in if e = a then loop (i + 1)
             else SOME {vertex = i, expected = e, actual = a}
          end
    in
      if Array.length got <> n then
        SOME {vertex = ~1, expected = n, actual = Array.length got}
      else loop 0
    end

  (* Print a verdict and return whether the result matched the reference. *)
  fun report (reference : int array, got : int array) : bool =
    case firstMismatch (reference, got) of
      NONE => (print "check: OK (coreness matches sequential baseline)\n"; true)
    | SOME {vertex = ~1, expected, actual} =>
        (print ("check: FAILED (length mismatch: expected " ^ Int.toString expected
                ^ ", got " ^ Int.toString actual ^ ")\n");
         false)
    | SOME {vertex, expected, actual} =>
        (print ("check: FAILED at vertex " ^ Int.toString vertex
                ^ " (expected " ^ Int.toString expected
                ^ ", got " ^ Int.toString actual ^ ")\n");
         false)
end
