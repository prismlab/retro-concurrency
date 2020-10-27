type sign = P | N
type value = Z of int | Error | Infinity of sign
type exp = Val of value | Div of exp * exp

effect DivBy0 : int -> value

let rec eval e = match e with
| Val v -> v
| Div (e1, e2) ->
    match eval e1, eval e2 with
    | Z v1, Z v2 ->
        if v2 = 0 then Sys.opaque_identity @@ perform (DivBy0 v1)
        else Z (v1 / v2)
    | Error, _ -> Error
    | Infinity s, _ -> Infinity s
    | _, Error -> Error
    | _, Infinity s -> Infinity s

let (/) n d = Div (Val (Z n), Val (Z d))

let ocaml e =
  match eval e with
  | v -> v
  | effect (DivBy0 _) k -> discontinue k Division_by_zero

let ios e =
  match eval e with
  | v -> v
  | effect (DivBy0 _) k -> continue k Error

let gsearch e =
  match eval e with
  | v -> v
  | effect (DivBy0 v1) k ->
      if v1 = 0 then continue k Error
      else if v1 > 0 then continue k (Infinity P)
      else continue k (Infinity N)

let _ = ocaml ((1/0))
