module Mc_handler

open FStar.All

type lam_kind = | Clam | Olam

noeq type exp =
  | EConst : v:int -> exp
  | EVar : v:string -> exp
  | EApp : fn:exp -> arg:exp -> exp
  | EAbs : k:lam_kind -> x:string -> body:exp -> exp
  | EArith : (f:int->int->int) -> e1:exp -> e2:exp -> exp
  | EHandle : e:exp -> h:handler -> exp
  | ERaise : label:string -> param:exp -> exp
  | EPerform : label:string -> param:exp -> exp

and handler =
  | HValue  : x:string -> e:exp -> handler
  | HExn    : label:string -> v:string -> e:exp -> rest:handler -> handler
  | HEffect : label:string -> v:string -> k:string -> e:exp -> rest:handler -> handler

noeq type env = string -> Tot (option value)

and value =
  | VInt  : n:int -> value
  | VCont : k:continuation -> value
  | VClos : e:exp{EAbs? e} -> v:env -> value
  | VEff : l:string -> k:continuation -> value
  | VExn : l:string -> value

and frame =
  | FArg : e:exp -> n:env -> frame
  | FFun : v:value -> frame
  | FArith1 : (f:int->int->int) -> e:exp -> n:env -> frame
  | FArith2 : (f:int->int->int) -> n:int -> frame

and fiber = list frame * (handler * env)

and continuation = l:list fiber{Cons? l}

noeq type ostack =
  | OS: continuation -> cstack -> ostack

and cstack =
  | CS: list frame -> option ostack -> cstack

noeq type stack =
  | O : ostack -> stack
  | C : cstack -> stack

noeq type term =
  | E : exp -> env -> term
  | V : value -> term

type state = term * stack

val empty_env : env
let empty_env = fun _ -> None

val extend_env : env -> string -> value -> Tot env
let extend_env g x t = fun x' -> if x = x' then Some t else g x'

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

let empty_continuation = [[], (HValue "x" (EVar "x"), empty_env)]

val step0 : term -> list frame -> ML (option (term * list frame))
let step0 t fs =
  match t,fs with
  (* Constant *)
  | E (EConst n) r, fs -> Some (V (VInt n), fs)

  (* Variable *)
  | E (EVar x) r, fs ->
      begin match r x with
      | None -> raise Stuck (* unbound variable; open term? *)
      | Some v -> Some (V v, fs)
      end

  (* Arithmetic *)
  | E (EArith f e1 e2) r, fs -> Some (E e1 r, FArith1 f e2 r::fs)
  | V (VInt n1), FArith1 f e2 r2::fs -> Some (E e2 r2, FArith2 f n1::fs)
  | V (VInt n2), FArith2 f n1::fs -> Some (V (VInt (f n1 n2)), fs)

  (* Function Application *)
  | E (EApp f x) r, fs -> Some (E f r, FArg x r::fs)
  | E (EAbs k x e) r, fs -> Some (V (VClos (EAbs k x e) r), fs)
  | V (VClos e v), FArg x r2::fs -> Some (E x r2, FFun (VClos e v)::fs)

  (* Continuation resumption *)
  | V (VCont k), FArg e1 r1::FArg e2 r2::fs ->
      Some (E e1 r1, FFun (VCont k)::FArg e2 r2::fs)
  | V (VClos e1 r1), FFun (VCont k)::FArg e2 r2::fs ->
      Some (E e2 r2, FFun (VCont k)::FFun(VClos e1 r1)::fs)

  (* Perform operation *)
  | E (EPerform l e) r, fs -> Some (E e r, FFun (VEff l empty_continuation)::fs)

  (* Raise exception *)
  | E (ERaise l e) r, fs -> Some (E e r, FFun (VExn l)::fs)

  | _ -> None

val ostep : term -> continuation -> cstack -> ML (option state)
let ostep t (k:continuation) cs =
  assert (Cons? k);
  match t, k with
  (* Return *)
  | V v, [[],_h] -> Some (V v, C cs) (* Return from OCaml to C *)
  | V v, ([],(h,r))::k' ->  (* Handler value return case *)
      let x,e = get_return_case h in
      Some (E e (extend_env r x v), O (OS k' cs))

  (* Function Application *)
  | V v, ((FFun (VClos (EAbs Olam x e) r)::fs,h)::k) ->
      Some (E e (extend_env r x v), O (OS ((fs,h)::k) cs))
  | V v, ((FFun (VClos (EAbs Clam x e) r)::fs,h)::k) -> (* External call *)
      Some (E e (extend_env r x v), C (CS [] (Some (OS ((fs,h)::k) cs))))

  (* Continuation resumption *)
  | V v, ((FFun (VCont k)::FFun(VClos (EAbs Olam x e) r)::fs,h)::k') ->
      Some (E e (extend_env r x v), O (OS (k @ ((fs,h)::k')) cs))

  (* Install handler *)
  | E (EHandle e h) r, k -> Some (E e r, O (OS (([],(h,r))::k) cs))

  (* Perform operation *)
  | V v, [FFun (VEff l k)::fs,h] ->
      (* Outermost handler has only the value case *)
      Some (E (ERaise "Unhandled_effect" (EConst 0)) empty_env, O (OS (k @ ([fs,h])) cs))
  | V v, ((FFun (VEff l k)::fs,(h,r))::(fs',h')::k') ->
      begin match get_effect_case h l with
      | Some (x,kv,e) ->
          let new_r = extend_env (extend_env r kv (VCont (k @ [fs,(h,r)]))) x v in
          Some (E e new_r, O (OS ((fs',h')::k') cs))
      | None -> Some (V v, O (OS ((FFun (VEff l (k @ [fs,(h,r)]))::fs',h')::k') cs))
      end

   (* Raise exception *)
   | V v, [FFun (VExn l)::fs,h] ->
      (* Outermost handler has only the value case *)
      let CS fs osopt = cs in
      Some (V v, C (CS (FFun (VExn l)::fs) osopt))
   | V v, ((FFun (VExn l)::fs,(h,r))::(fs',h')::k') ->
       begin match get_exn_case h l with
       | Some (x,e) ->
           let new_r = extend_env r x v in
           Some (E e new_r, O (OS ((fs',h')::k') cs))
       | None -> Some (V v, O (OS ((FFun (VExn l)::fs',h')::k') cs))
       end

  (* Other local operations *)
  | _, (fs,h)::k ->
      begin match step0 t fs with
      | Some (t',fs') -> Some (t',O (OS ((fs',h)::k) cs))
      | None -> raise Stuck (* No further reduction *)
      end

val cstep : term -> list frame -> option ostack -> ML (option state) 
let cstep t fs osopt =
  match t, fs with
  (* Return value from C to OCaml *)
  | V v, [] ->
      begin match osopt with
      | None -> None
      | Some os -> Some (V v, O os)
      end

  (* Function Application *)
  | V v, FFun (VClos (EAbs Olam x e) r2)::fs -> (* callback *)
      Some (E e (extend_env r2 x v), O (OS empty_continuation (CS fs osopt)))
  | V v, FFun (VClos (EAbs Clam x e) r2)::fs ->
      Some (E e (extend_env r2 x v), C (CS fs osopt))

  (* Raise exception *)
  | V v, FFun (VExn l)::fs ->
      begin match osopt with
      | None -> (* no handler *)
          FStar.IO.print_string ("Unhandled exception: " ^ l ^ "\n");
          raise Stuck
      | Some (OS ((fs,h)::k) cs) ->
          Some (V v, O (OS ((FFun (VExn l)::fs,h)::k) cs))
      end

  (* Other local operations *)
  | _, fs ->
      begin match step0 t fs with
      | Some (t',fs') -> Some (t', C (CS fs' osopt))
      | None -> raise Stuck (* No further reduction *)
      end

val step : state -> ML (option state)
let step (term,stack) =
  match stack with
  | O (OS k cs) -> ostep term k cs
  | C (CS fs osopt) -> cstep term fs osopt

val s : state -> ML state
let s st = match step st with
           | None -> failwith "unexpected"
           | Some st -> st

val eval_st : state -> ML state
let rec eval_st s =
  match step s with
  | None -> s
  | Some s' -> eval_st s'

let init e = E e empty_env, C (CS [] None)

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

let olam x e = EAbs Olam x e

let clam x e = EAbs Clam x e

let c n = EConst n

let perform l e = EPerform l e

let case_val x e = HValue x e

let case_eff l v k e r = HEffect l v k e r

let case_exn l v e r = HExn l v e r

let handle e h = EHandle e h

let raise_ l e = ERaise l e

let continue k e = app [var k; olam "x" (var "x"); e]

let discontinue k l e = app [var k; olam "x" (raise_ l (var "x")); e]

let int_state_to_string s = 
  match s with
  | V (VInt n), _ -> string_of_int n
  | _ -> "unexpected state"

let (+) e1 e2 = EArith (+) e1 e2

let callback e = app [olam "x" e; c 0]

(******************************************************************************)
(* Examples *)
(******************************************************************************)

let ex1 = olam "x" (var "x")
(* Expect [fun x -> x] for [eval ex1] in utop *)

let ex2 = app [olam "x" (var "x"); olam "y" (var "y")]
(* Expect [fun y -> y] for [eval ex2] in utop*)

let ex3 = callback (
            handle (perform "x" (c 0))
            (case_exn "Unhandled_effect" "v" (c 42)
            (case_val "impossible" (var "impossible"))))
(* Expect [42] for [int_state_to_string (eval ex3)] in utop *)

let inc_handler e =
  handle e
  (case_eff "Inc" "v" "k" (continue "k" ((var "v") + (c 1)))
  (case_val "x" (var "x")))

let ex4 = callback (inc_handler (perform "Inc" (c 0)))
(* Expect [1] for [int_state_to_string (eval ex4) in utop] *)

let ex5 = callback (inc_handler (perform "Inc" (c 0) + perform "Inc" (c 1)))
(* Expect [3] for [int_state_to_string (eval ex5) in utop] *)

let ex6 = callback (
            handle (perform "eff" (c 0))
            (case_eff "eff" "v" "k" (discontinue "k" "exn" (c 42))
            ((case_exn "exn" "v'" (var "v'"))
            (case_val "_" (var "_")))))
(* Expect [42] for [int_state_to_string (eval ex6) in utop] *)


let ex7 = handle (c 0)
          (case_eff "eff" "v" "k" (var "v")
          (case_val "v" (var "v")))
(* Expect [exception Stuck] for [eval ex7] in utop. Handlers cannot be installed in C. *)

let ex8 = perform "eff" (c 0)
(* Expect [exception Stuck] for [eval ex8] in utop. Effects cannot be performed in C. *)

let run () =
  begin match eval ex1 with
  | V (VClos (EAbs Olam "x" (EVar "x")) _), _ -> ()
  | _ -> failwith "ex1 failed"
  end;
  begin match eval ex2 with
  | V (VClos (EAbs Olam "y" (EVar "y")) _), _ -> ()
  | _ -> failwith "ex2 failed"
  end;
  if not (int_state_to_string (eval ex3) = "42") then failwith "ex3 failed";
  if not (int_state_to_string (eval ex4) = "1") then failwith "ex4 failed";
  if not (int_state_to_string (eval ex5) = "3") then failwith "ex5 failed";
  if not (int_state_to_string (eval ex6) = "42") then failwith "ex6 failed";
  try ignore (eval ex7); failwith "ex7 failed" with | Stuck -> () | e -> raise e;
  try ignore (eval ex8); failwith "ex8 failed" with | Stuck -> () | e -> raise e
