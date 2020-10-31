module type Handler = sig
  type 'a eff
  type ('a,'b) continuation
  type ('a, 'b) handler =
    { ret_case : 'a -> 'b;
      eff_case : 'c. 'c eff -> ('c, 'b)continuation -> 'b }

  val perform : 'a eff -> 'a
  val continue : ('a,'b) continuation -> 'a -> 'b
  val discontinue : ('a,'b) continuation -> exn -> 'b
  val match_ : (unit -> 'a) -> ('a, 'b) handler -> 'b
end

module Handler : Handler = struct
  type ('a, 'b) handler =
    { ret_case : 'a -> 'b;
      eff_case : 'c. 'c eff -> ('c, 'b)continuation -> 'b }

  let perform e = failwith "not implemented"
  let continuat k v = failwith "not implemented"
  let discontinue k e = failwith "not implemented"

  effect E : int -> int
  effect F : string -> string

  type _ eff += E : int -> int eff
              | F : string -> string eff

  type t = A | B

  let run f = match f () with
  | A -> true
  | B -> false
  | effect (E 42) k -> ignore (continue k 43); true
  | effect (F "42") k -> ignore (continue k "43"); false

  let eff_case : type c. c eff -> (c, 'b) continuation -> 'b =
    function | E 42 -> (fun k1 -> continue k1 43)
             | F "42" -> (fun k2 -> continue k2 "43")
             | e -> (fun k -> match perform e with
                              | v -> continue k v
                              | exception e -> discontinue k e)

  let h1 =
    { ret_case = (function A -> true
                    | B -> false);
      eff_case; }

end
