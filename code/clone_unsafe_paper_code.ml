effect E : unit

let foo () = perform E

let bar f =
  let r = ref 0 in
  f ();
  r := !r + 1;
  !r

let _ = match bar foo with
| v -> v
| effect E k ->
    let k' = Obj.clone_continuation k in
    let r1 = continue k () in
    let r2 = continue k' () in
    Printf.printf "%d %d\n" r1 r2;
    0
