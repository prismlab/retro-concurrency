external ocaml_to_c : unit -> int = "ocaml_to_c"

exception E1
exception E2

let c_to_ocaml () = raise E1;;
Callback.register "c_to_ocaml" c_to_ocaml;;

let omain () =
  try (* h1 *)
    try (* h2 *)
      ocaml_to_c ()
    with E2 -> -42
  with E1 -> 42;;

assert (omain () = 42)
