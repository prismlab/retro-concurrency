module Handler

open FStar.All

noeq type exp =
  | EConst : v:int -> exp
  | EVar : v:string -> exp
  | EApp : fn:exp -> arg:exp -> exp
  | EAbs : x:string -> body:exp -> exp
  | EArith : (f:int->int->int) -> e1:exp -> e2:exp -> exp
	| EPerform : label:string -> param:exp -> exp
	| EHandle : e:exp -> h:handler -> exp

and handler =
  | HValue  : x:string -> e:exp -> handler
  | HEffect : label:string -> v:string -> k:string -> e:exp -> rest:handler -> handler

and env = string -> Tot (option value)

and value =
  | VInt  : n:int -> value
  | VCont : k:continuation -> value
  | VClos : e:exp (*EAbs? e *) -> v:env -> value
  | VOper : l:string -> k:continuation -> value

and frame =
  | FArg : e:exp -> n:env -> frame
  | FFun : v:value -> frame
  | FArith1 : (f:int->int->int) -> e:exp -> n:env -> frame
  | FArith2 : (f:int->int->int) -> n:int -> frame
  
and fiber = list frame * env * handler

and continuation = list fiber

and term =
  | E : exp -> term
  | V : value -> term

type state = term * env * continuation

val empty : env
let empty = fun _ -> None

val extend : env -> string -> value -> Tot env
let extend g x t = fun x' -> if x = x' then Some t else g x'

let rec get_return_case h = 
  match h with
  | HEffect _ _ _ _ h -> get_return_case h
  | HValue x e -> x,e

let rec get_effect_case h l =
  match h with
  | HValue _ _ -> None
  | HEffect l' x kv e h' -> 
      if l = l' then Some(x,kv,e) 
      else get_effect_case h' l

exception Stuck

val step : s:state -> ML (option state)
let step s =
  match s with
  | E (EConst n), r, k -> Some (V (VInt n), r, k)
  | E (EVar x), r, k ->
      begin match r x with
      | None -> raise Stuck (* unbound variable! *)
      | Some v -> Some (V v, r, k)
      end

  (* Arithmetic *)
  | E (EArith f e1 e2), r, (fs,r2,h)::k -> Some (E e1, r, (FArith1 f e2 r::fs,r2,h)::k)
  | V (VInt n1), _, (FArith1 f e2 r2::fs,r,h)::k -> Some (E e2, r2, (FArith2 f n1::fs,r,h)::k)
  | V (VInt n2), r, (FArith2 f n1::fs,r2,h)::k -> Some (V (VInt (f n1 n2)), r, (fs,r2,h)::k)
  
  (* Function Application *)
  | E (EApp f x), r, (fs,r2,h)::k -> Some (E f, r, (FArg x r::fs,r2,h)::k)
  | E (EAbs x e), r, k -> Some (V (VClos (EAbs x e) r), r, k)
  | V (VClos e v), _, (FArg x r2::fs,r3,h)::k -> Some (E x, r2, (FFun (VClos e v)::fs,r3,h)::k)
  | V v, _, (FFun (VClos (EAbs x e) r2)::fs,r3,h)::k -> Some (E e, extend r2 x v, (fs,r3,h)::k)

  (* Continuation resumption *)
  | V (VCont k), _, (FArg x r2::fs,r3,h)::k' -> Some (E x, r2, (FFun (VCont k)::fs,r3,h)::k')
  | V v, r, (FFun (VCont k)::fs,r2,h)::k' -> Some (V v, r, k @ ((fs,r2,h)::k'))

  (* Install handler *)
  | E (EHandle e h), r, k -> Some (E e, r, ([],r,h)::k)

  (* Perform operation *)
  | E (EPerform l e), r, (fs, r2, h)::k -> Some (E e, r, (FFun (VOper l [])::fs,r2,h)::k)
  | V v, r, (FFun (VOper l k)::fs,r2,h)::[] -> raise Stuck 
                               (* Outermost handler only has the return case *)
  | V v, r, (FFun (VOper l k)::fs2,r2,h2)::(fs3,r3,h3)::k' -> 
    begin match get_effect_case h2 l with
    | Some (x,kv,e) -> 
        let new_r = extend (extend r2 kv (VCont (k @ [(fs2,r2,h2)]))) x v in
        Some (E e, new_r, (fs3,r3,h3)::k')
    | None -> Some (V v, r, (FFun (VOper l (k @ [(fs2,r2,h2)]))::fs3,r3,h3)::k')
    end

  (* Return *)
  | V v, _, ([],r,h)::k -> let x,e = get_return_case h in Some (E e, extend r x v, k)
  | V v, r, [] -> None (* No further reduction *)

  (* Stuck *)
  | _, _, _ -> raise Stuck (* impossible *)

val eval_st : state -> ML state
let rec eval_st s =
  match step s with
  | None -> s
  | Some s' -> eval_st s'

let empty_continuation : continuation = [([], empty, HValue "x" (EVar "x"))]

let init e = (E e, empty, empty_continuation)

let eval e = eval_st (init e)

(******************************************************************************)
(* Helper Functions *)
(******************************************************************************)

let var x = EVar x

val app : l:list exp{Cons? l} -> Tot exp
let app l =
  match l with
  | [x] -> x
  | x::y::xs -> FStar.List.Tot.fold_left (fun expr v -> EApp expr v) (EApp x y) xs

let lam x e = EAbs x e

let c n = EConst n

let perform l v = EPerform l v

let case_val x e = HValue x e

let case_eff l v k e r = HEffect l v k e r

let handle e h = EHandle e h

let continue k e = EApp (EVar k) e

let int_state_to_string s = 
  match s with
  | (V (VInt n), _,_) -> string_of_int n
  | _ -> "unexpected state"

let (+) e1 e2 = EArith (+) e1 e2

(******************************************************************************)
(* Examples *)
(******************************************************************************)

let ex1 = lam "x" (var "x")

let ex2 = app [lam "x" (var "x"); lam "y" (var "y")]

let ex3 = perform "x" (c 0)

let ex4 = handle (perform "E" (c 0))
          (case_eff "E" "v" "k" (continue "k" ((var "v") + (c 1)))
          (case_val "x" (var "x")))

let () = (* eval ex1; eval ex2; eval ex3; eval ex4 *) ()
