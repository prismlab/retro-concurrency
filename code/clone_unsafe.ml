effect E : unit

let foo () =
  let r = Atomic.make 0 in
  perform E;
  Atomic.set r (Atomic.get r + 1);
  Atomic.get r

let bar () =
  let r = ref 0 in
  perform E;
  r := !r + 1;
  !r

let run f = match f () with
| v -> v
| effect E k ->
    let k' = Obj.clone_continuation k in
    let _ = Printf.printf "%d\n" (continue k ()) in
    let _ = Printf.printf "%d\n" (continue k' ()) in
    0

let _ = print_endline "----Expected----"
let _ = print_endline "1"
let _ = print_endline "2"
let _ = print_endline "----Atomic.ref----"
let _ = run foo
let _ = print_endline "----ref----"
let _ = run bar
