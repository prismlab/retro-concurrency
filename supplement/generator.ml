let n = try int_of_string (Sys.argv.(1)) with _ -> 25

(* Using effect handlers, we can derive the generator from the iterator of any
 * data structure *)
module MkGen (S :sig
  type 'a t
  val iter : ('a -> unit) -> 'a t -> unit
end) : sig
  val gen : 'a S.t -> (unit -> 'a option)
end = struct
  let gen : type a. a S.t -> (unit -> a option) = fun l ->
    let module M = struct effect Yield : a -> unit end in
    let open M in
    let rec r = ref (fun () ->
      match S.iter (fun v -> perform (Yield v)) l with
      | () -> None
      | effect (Yield v) k ->
          r := (fun () -> continue k ());
          Some v)
    in
    fun () -> !r ()
end

(* Deriving the generator for a list *)
module L = MkGen (struct
  type 'a t = 'a list
  let iter = List.iter
end)

(* Consider a binary tree *)
type 'a tree =
| Leaf
| Node of 'a tree * 'a * 'a tree

(* Make a complete binary tree of depth [n] *)
let rec make = function
  | 0 -> Leaf
  | n -> let t = make (n-1) in Node (t,n,t)

let rec iter f = function
  | Leaf -> ()
  | Node (l, x, r) -> iter f l; f x; iter f r

(* Deriving the generator for the binary tree *)
module T = MkGen(struct
  type 'a t = 'a tree
  let iter = iter
end)

let main () =
  let next = T.gen (make n) in
  let rec consume () =
    match next () with
    | None -> ()
    | Some _ -> consume ()
  in
  consume ()

let _ = main ()
