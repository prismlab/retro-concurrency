module Utlc

open FStar.All

type exp =
  | EVar : v:string -> exp
  | EApp : fn:exp -> arg:exp -> exp
  | EAbs : x:string -> body:exp -> exp

type abs = e:exp{EAbs? e}

noeq type env = string -> Tot (option value)

and value =
  | Const : nat -> value
  | Clos : e:abs -> v:env -> value

val empty : env
let empty = fun _ -> None

val extend : env -> string -> value -> Tot env
let extend g x t = fun x' -> if x = x' then Some t else g x'

noeq type frame =
  | Arg : e:exp -> n:env -> frame
  | Fun : v:value{Clos? v} -> frame

noeq type term =
  | E : exp -> term
  | V : value -> term

type state = term * env * list frame

exception Stuck

val step : state -> ML (option state)
let step s =
  match s with
  | E (EVar x), r, k ->
      begin match r x with
      | None -> raise Stuck (* unbound variable! *)
      | Some v -> Some (V v, r, k)
      end
  | E (EApp f x), r, k -> Some (E f, r, Arg x r::k)
  | E (EAbs x e), r, k -> Some (V (Clos (EAbs x e) r), r, k)
  | V (Clos e v), r, Arg x r2::k -> Some (E x, r2, Fun (Clos e v)::k)
  | V v, r, Fun (Clos (EAbs x e) r2)::k -> Some (E e, extend r2 x v, k)
  | V v, r, [] -> None (* No further reduction *)
  | V v, r, _ -> raise Stuck (* impossible *)

val eval_st : state -> ML state
let rec eval_st s =
  match step s with
  | None -> s
  | Some s' -> eval_st s'

let eval e = eval_st (E e, empty, [])

let ex1 = eval (EAbs "x" (EVar "x"))
