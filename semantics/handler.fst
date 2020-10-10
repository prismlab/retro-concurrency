module Handler

open FStar.All

noeq type exp =
  | EConst : v:int -> exp
  | EVar : v:string -> exp
  | EApp : fn:exp -> arg:exp -> exp
  | EAbs : x:string -> body:exp -> exp
  | EArith : (f:int->int->int) -> e1:exp -> e2:exp -> exp
	| EHandle : e:exp -> h:handler -> exp
  | ERaise : label:string -> param:exp -> exp
	| EPerform : label:string -> param:exp -> exp

and handler =
  | HValue  : x:string -> e:exp -> handler
  | HExn    : label:string -> v:string -> e:exp -> rest:handler -> handler
  | HEffect : label:string -> v:string -> k:string -> e:exp -> rest:handler -> handler

and env = string -> Tot (option value)

and value =
  | VInt  : n:int -> value
  | VCont : k:continuation -> value
  | VClos : e:exp (*EAbs? e *) -> v:env -> value
  | VEff : l:string -> k:continuation -> value
  | VExn : l:string -> value

and frame =
  | FArg : e:exp -> n:env -> frame
  | FFun : v:value -> frame
  | FArith1 : (f:int->int->int) -> e:exp -> n:env -> frame
  | FArith2 : (f:int->int->int) -> n:int -> frame
  
and fiber = list frame * env * handler

and continuation = list fiber

noeq type state = 
  | E: exp -> env -> continuation -> state
  | V: value -> continuation -> state

val empty : env
let empty = fun _ -> None

val extend : env -> string -> value -> Tot env
let extend g x t = fun x' -> if x = x' then Some t else g x'

let rec get_return_case h = 
  match h with
  | HEffect _ _ _ _ h -> get_return_case h
  | HExn _ _ _ h -> get_return_case h
  | HValue x e -> x,e

let rec get_effect_case h l =
  match h with
  | HValue _ _ -> None
  | HExn _ _ _ h -> get_effect_case h l
  | HEffect l' x kv e h' -> 
      if l = l' then Some(x,kv,e) 
      else get_effect_case h' l

let rec get_exn_case h l =
  match h with
  | HValue _ _ -> None
  | HEffect _ _ _ _ h -> get_exn_case h l
  | HExn l' x e h' ->
      if l = l' then Some (x,e)
      else get_exn_case h' l

exception Stuck

val step : s:state -> ML (option state)
let step s =
  match s with
  | E (EConst n) r k -> 
      Some (V (VInt n) k)
  | E (EVar x)  r  k ->
      begin match r x with
      | None -> raise Stuck (* unbound variable! *)
      | Some v -> Some (V v k)
      end

  (* Arithmetic *)
  | E (EArith f e1 e2) r ((fs,r2,h)::k) -> 
      Some (E e1 r ((FArith1 f e2 r::fs,r2,h)::k))
  | V (VInt n1) ((FArith1 f e2 r2::fs,r,h)::k) -> 
      Some (E e2 r2 ((FArith2 f n1::fs,r,h)::k))
  | V (VInt n2) ((FArith2 f n1::fs,r2,h)::k) -> 
      Some (V (VInt (f n1 n2)) ((fs,r2,h)::k))
  
  (* Function Application *)
  | E (EApp f x) r ((fs,r2,h)::k) -> Some (E f r ((FArg x r::fs,r2,h)::k))
  | E (EAbs x e) r k -> Some (V (VClos (EAbs x e) r) k)
  | V (VClos e v) ((FArg x r2::fs,r3,h)::k) -> 
      Some (E x r2 ((FFun (VClos e v)::fs,r3,h)::k))
  | V v ((FFun (VClos (EAbs x e) r2)::fs,r3,h)::k) -> 
      Some (E e (extend r2 x v) ((fs,r3,h)::k))

  (* Continuation resumption *)
  | V (VCont k) ((FArg e1 r1::FArg e2 r2::fs,r,h)::k') -> 
      Some (E e1 r1 ((FFun (VCont k)::FArg e2 r2::fs,r,h)::k'))
  | V (VClos e1 r1) ((FFun (VCont k)::FArg e2 r2::fs,r,h)::k') ->
      Some (E e2 r2 ((FFun (VCont k)::FFun(VClos e1 r1)::fs,r,h)::k'))
  | V v ((FFun (VCont k)::FFun(VClos (EAbs x e) r2)::fs,r,h)::k') ->
      Some (E e (extend r2 x v) (k @ ((fs,r,h)::k')))

  (* Install handler *)
  | E (EHandle e h) r k -> Some (E e r (([],r,h)::k))

  (* Perform operation *)
  | E (EPerform l e) r ((fs, r2, h)::k) -> 
      Some (E e r ((FFun (VEff l [])::fs,r2,h)::k))
  | V v ((FFun (VEff l k)::fs,r2,h)::[]) -> 
      (* Outermost handler only has the return case *)
      Some (E (ERaise "Unhandled_effect" (EConst 0)) empty (k @ ([fs,r2,h])))
  | V v ((FFun (VEff l k)::fs2,r2,h2)::(fs3,r3,h3)::k') -> 
    begin match get_effect_case h2 l with
    | Some (x,kv,e) -> 
        let new_r = extend (extend r2 kv (VCont (k @ [(fs2,r2,h2)]))) x v in
        Some (E e new_r ((fs3,r3,h3)::k'))
    | None -> Some (V v ((FFun (VEff l (k @ [(fs2,r2,h2)]))::fs3,r3,h3)::k'))
    end

   (* Raise exception *)
   | E (ERaise l e) r ((fs, r2, h)::k) ->
       Some (E e r ((FFun (VExn l)::fs,r2,h)::k))
   | V v ((FFun (VExn l)::fs,r2,h)::[]) ->
       (* Outermost handler only has return case *)
       FStar.IO.print_string ("Unhandled exception: " ^ l ^ "\n");
       raise Stuck
   | V v ((FFun (VExn l)::fs2,r2,h2)::(fs3,r3,h3)::k') ->
       begin match get_exn_case h2 l with
       | Some (x,e) ->
           let new_r = extend r2 x v in
           Some (E e new_r ((fs3,r3,h3)::k'))
       | None -> Some (V v ((FFun (VExn l)::fs3,r3,h3)::k'))
       end

  (* Return *)
  | V v (([],r,h)::k) -> let x,e = get_return_case h in Some (E e (extend r x v) k)
  | V v [] -> None (* No further reduction *)

  (* Stuck *)
  | _ -> raise Stuck (* impossible *)

val eval_st : state -> ML state
let rec eval_st s =
  match step s with
  | None -> s
  | Some s' -> eval_st s'

let empty_continuation : continuation = [([], empty, HValue "x" (EVar "x"))]

let init e = E e empty empty_continuation

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

let perform l e = EPerform l e

let case_val x e = HValue x e

let case_eff l v k e r = HEffect l v k e r

let case_exn l v e r = HExn l v e r

let handle e h = EHandle e h

let raise_ l e = ERaise l e

let continue k e = app [var k; lam "x" (var "x"); e]

let discontinue k l e = app [var k; lam "x" (raise_ l (var "x")); e]

let int_state_to_string s = 
  match s with
  | (V (VInt n) _) -> string_of_int n
  | _ -> "unexpected state"

let (+) e1 e2 = EArith (+) e1 e2

(******************************************************************************)
(* Examples *)
(******************************************************************************)

let ex1 = lam "x" (var "x") 
(* Expect [fun x -> x] for [eval ex1] in utop *)

let ex2 = app [lam "x" (var "x"); lam "y" (var "y")]
(* Expect [fun y -> y] for [eval ex2] in utop*)

let ex3 = handle (perform "x" (c 0))
          (case_exn "Unhandled_effect" "v" (c 42)
          (case_val "impossible" (var "impossible")))
(* Expect [42] for [int_state_to_string (eval ex3)] in utop *)

let inc_handler e =
  handle e
  (case_eff "Inc" "v" "k" (continue "k" ((var "v") + (c 1)))
  (case_val "x" (var "x")))

let ex4 = inc_handler (perform "Inc" (c 0))
(* Expect [1] for [int_state_to_string (eval ex4) in utop] *)

let ex5 = inc_handler (perform "Inc" (c 0) + perform "Inc" (c 1))
(* Expect [3] for [int_state_to_string (eval ex5) in utop] *)

let ex6 = handle (perform "eff" (c 0))
          (case_eff "eff" "v" "k" (discontinue "k" "exn" (c 42))
          ((case_exn "exn" "v'" (var "v'"))
           (case_val "_" (var "_"))))
(* Expect [42] for [int_state_to_string (eval ex6) in utop] *)
