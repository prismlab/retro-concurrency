type lam_kind = Clam | Olam

type exp =
  | EConst : int -> exp
  | EVar : string -> exp
  | EApp : exp * exp -> exp
  | EAbs : lam_kind * string * exp -> exp
  | EArith : (int->int->int) * exp * exp -> exp
  | EMatchWith : exp * handler -> exp
  | ERaise : string * exp -> exp
  | EPerform : string * exp -> exp

and handler =
  | HValue  : string * exp -> handler
  | HExn    : string * string * exp * handler -> handler
  | HEffect : string * string * string * exp * handler -> handler

type env = string -> value option

and value =
  | VInt  : int -> value
  | VCont : continuation -> value
  | VClos : exp * env -> value
  | VEff : string * continuation -> value
  | VExn : string -> value

and frame =
  | FArg : exp * env -> frame
  | FFun : value -> frame
  | FArith1 : (int->int->int) * exp * env -> frame
  | FArith2 : (int->int->int) * int -> frame

and fiber = frame list * (handler * env)

and continuation = fiber list

type ostack =
  | OS: continuation * cstack -> ostack

and cstack =
  | CS: frame list * ostack option -> cstack

type stack =
  | O : ostack -> stack
  | C : cstack -> stack

type term =
  | E : exp * env -> term
  | V : value -> term

type state = term * stack

let empty_env = fun _ -> None

let extend_env g x t = fun x' -> if x = x' then Some t else g x'

let rec get_return_case h =
  match h with
  | HEffect (_,_,_,_,h) -> get_return_case h
  | HExn (_,_,_,h) -> get_return_case h
  | HValue (x,e) -> x,e

let rec get_effect_case h l =
  match h with
  | HValue (_,_) -> None
  | HExn (_,_,_,h) -> get_effect_case h l
  | HEffect (l', x, kv, e, h') ->
      if l = l' then Some(x,kv,e)
      else get_effect_case h' l

let rec get_exn_case h l =
  match h with
  | HValue _ -> None
  | HEffect (_,_,_,_,h) -> get_exn_case h l
  | HExn (l', x, e, h') ->
      if l = l' then Some (x,e)
      else get_exn_case h' l

exception Stuck

let empty_continuation = [[], (HValue ("x", EVar "x"), empty_env)]

let admin_step ?(log=false) t fs =
  match t,fs with
  (* Const -- no corresponding rule in the paper *)
  | E (EConst n, r), fs ->
      if log then print_string "Const ";
      Some (V (VInt n), fs)

  (* Var *)
  | E (EVar x, r), fs ->
      begin match r x with
      | None -> raise Stuck (* unbound variable; open term? *)
      | Some v ->
          if log then print_string "Var ";
          Some (V v, fs)
      end

  (* Arith1 *)
  | E (EArith (f, e1, e2), r), fs ->
      if log then print_string "Arith1 ";
      Some (E (e1, r), FArith1 (f, e2, r)::fs)
  (* Arith2 *)
  | V (VInt n1), FArith1 (f, e2, r2)::fs ->
      if log then print_string "Arith2 ";
      Some (E (e2, r2), FArith2(f,n1)::fs)
  (* Arith3 *)
  | V (VInt n2), FArith2 (f, n1)::fs ->
      if log then print_string "Arith3 ";
      Some (V (VInt (f n1 n2)), fs)

  (* App1 *)
  | E (EApp (f, x), r), fs ->
      if log then print_string "App1 ";
      Some (E (f, r), FArg (x, r)::fs)
  (* App2 *)
  | E (EAbs (k, x, e), r), fs ->
      if log then print_string "App2 ";
      Some (V (VClos (EAbs (k, x, e), r)), fs)
  (* App3 *)
  | V (VClos (e, v)), FArg (x, r2)::fs ->
      if log then print_string "App3 ";
      Some (E (x, r2), FFun (VClos (e, v))::fs)

  (* Resume1 *)
  | V (VCont k), FArg (e1, r1)::FArg (e2, r2)::fs ->
      if log then print_string "Resume1 ";
      Some (E (e1, r1), FFun (VCont k)::FArg (e2, r2)::fs)
  (* Resume2 *)
  | V (VClos (e1, r1)), FFun (VCont k)::FArg (e2, r2)::fs ->
      if log then print_string "Resume2 ";
      Some (E (e2, r2), FFun (VCont k)::FFun(VClos (e1, r1))::fs)

  (* Perform *)
  | E (EPerform (l, e), r), fs ->
      if log then print_string "Perform ";
      Some (E (e, r), FFun (VEff (l, empty_continuation))::fs)

  (* Raise *)
  | E (ERaise (l, e), r), fs ->
      if log then print_string "Raise ";
      Some (E (e, r), FFun (VExn l)::fs)

  | _ -> None

let ostep ?(log=false) t (k:continuation) cs =
  match t, k with
  (* CallO *)
  | V v, (FFun (VClos (EAbs (Olam, x, e), r))::fs,h)::k ->
      if log then print_string "CallO ";
      Some (E (e, extend_env r x v), O (OS ((fs,h)::k, cs)))
  (* ExtCall *)
  | V v, (FFun (VClos (EAbs (Clam, x, e), r))::fs,h)::k ->
      if log then print_string "ExtCall ";
      Some (E (e, extend_env r x v), C (CS ([], Some (OS ((fs,h)::k, cs)))))

  (* RetToC *)
  | V v, [[],_h] ->
      if log then print_string "RetToC ";
      Some (V v, C cs)
  (* RetFib *)
  | V v, ([],(h,r))::k' ->
      if log then print_string "RetFib ";
      let x,e = get_return_case h in
      Some (E (e, extend_env r x v), O (OS (k', cs)))

  (* Handle *)
  | E (EMatchWith (e, h), r), k ->
      if log then print_string "Handle ";
      Some (E (e, r), O (OS (([],(h,r))::k, cs)))

  (* EffUnHn *)
  | V v, [FFun (VEff (l, k))::fs,h] ->
      (* Outermost handler has only the value case *)
      if log then print_string "EffUnHn ";
      Some (E (ERaise ("Unhandled_effect", EConst 0), empty_env), O (OS (k @ ([fs,h]), cs)))
  | V v, (FFun (VEff (l, k))::fs,(h,r))::(fs',h')::k' ->
      begin match get_effect_case h l with
      (* EffHn *)
      | Some (x,kv,e) ->
          if log then print_string "EffHn ";
          let new_r = extend_env (extend_env r kv (VCont (k @ [fs,(h,r)]))) x v in
          Some (E (e, new_r), O (OS ((fs',h')::k', cs)))
      (* EffFwd *)
      | None ->
          if log then print_string "EffFwd ";
          Some (V v, O (OS ((FFun (VEff (l, k @ [fs,(h,r)]))::fs',h')::k', cs)))
      end

   (* ExnFwdC *)
   | V v, [FFun (VExn l)::fs,h] ->
      (* Outermost handler has only the value case *)
      let CS (fs,osopt) = cs in
      if log then print_string "ExnFwdC ";
      Some (V v, C (CS (FFun (VExn l)::fs, osopt)))
   | V v, ((FFun (VExn l)::fs,(h,r))::(fs',h')::k') ->
       (* ExnHn *)
       begin match get_exn_case h l with
       | Some (x,e) ->
           let new_r = extend_env r x v in
           if log then print_string "ExnHn ";
           Some (E (e, new_r), O (OS ((fs',h')::k', cs)))
       (* ExnFwdFib *)
       | None ->
           if log then print_string "ExnFwdFib ";
           Some (V v, O (OS ((FFun (VExn l)::fs',h')::k', cs)))
       end

  (* Resume *)
  | V v, (FFun (VCont k)::FFun(VClos (EAbs (Olam, x, e), r))::fs,h)::k' ->
      if log then print_string "Resume ";
      Some (E (e, extend_env r x v), O (OS (k @ ((fs,h)::k'), cs)))

  (* AdminO *)
  | _, (fs,h)::k ->
      begin match admin_step ~log t fs with
      | Some (t',fs') ->
          if log then print_string "AdminO ";
          Some (t',O (OS ((fs',h)::k, cs)))
      | None -> raise Stuck (* No further reduction *)
      end
  | _, [] -> raise Stuck

let cstep ?(log=false) t fs osopt =
  match t, fs with
  (* RetToO *)
  | V v, [] ->
      begin match osopt with
      | None -> None
      | Some os ->
          if log then print_string "RetToO ";
          Some (V v, O os)
      end

  (* Callback *)
  | V v, FFun (VClos (EAbs (Olam, x, e), r2))::fs ->
      if log then print_string "Callback ";
      Some (E (e, extend_env r2 x v), O (OS (empty_continuation, CS (fs, osopt))))
  (* CallC *)
  | V v, FFun (VClos (EAbs (Clam, x, e), r2))::fs ->
      if log then print_string "CallC ";
      Some (E (e, extend_env r2 x v), C (CS (fs, osopt)))

  (* ExnFwdO *)
  | V v, FFun (VExn l)::fs ->
      begin match osopt with
      | Some (OS ((fs,h)::k, cs)) ->
          if log then print_string "ExnFwdO ";
          Some (V v, O (OS ((FFun (VExn l)::fs,h)::k, cs)))
      | _ -> (* no handler *)
          print_string ("Unhandled exception: " ^ l ^ "\n");
          raise Stuck
      end

  (* AdminC *)
  | _, fs ->
      begin match admin_step ~log t fs with
      | Some (t',fs') ->
          if log then print_string "AdminC ";
          Some (t', C (CS (fs', osopt)))
      | None -> raise Stuck (* No further reduction *)
      end

let step ?(log=false) (term,stack) =
  match stack with
  (* StepC *)
  | C (CS (fs, osopt)) ->
      let r = cstep ~log term fs osopt in
      begin match r with
      | Some _ -> if log then print_endline "StepC"
      | _ -> ()
      end;
      r
  (* StepO *)
  | O (OS (k, cs)) ->
      let r = ostep ~log term k cs in
      begin match r with
      | Some _ -> if log then print_endline "StepO"
      | _ -> ()
      end;
      r

let s st = match step st with
           | None -> failwith "unexpected"
           | Some st -> st

let rec eval_st ?(log=false) s =
  match step ~log s with
  | None -> s
  | Some s' -> eval_st ~log s'

let init e = E (e, empty_env), C (CS ([], None))

let eval ~log e = eval_st ~log (init e)

(******************************************************************************)
(* Helper Functions *)
(******************************************************************************)

let var x = EVar x

let app l =
  match l with
  | [] -> failwith "app"
  | [x] -> x
  | x::y::xs -> List.fold_left (fun expr v -> EApp (expr, v)) (EApp (x, y)) xs

let olam x e = EAbs (Olam, x, e)

let clam x e = EAbs (Clam, x, e)

let c n = EConst n

let perform l e = EPerform (l, e)

let case_val x e = HValue (x, e)

let case_eff l v k e r = HEffect (l, v, k, e, r)

let case_exn l v e r = HExn (l, v, e, r)

let handle e h = EMatchWith (e, h)

let raise_ l e = ERaise (l, e)

let continue k e = app [var k; olam "x" (var "x"); e]

let discontinue k l e = app [var k; olam "x" (raise_ l (var "x")); e]

let int_state_to_string s =
  match s with
  | V (VInt n), _ -> string_of_int n
  | _ -> "unexpected state"

let (+) e1 e2 = EArith ((+), e1, e2)

let callback e = app [olam "x" e; c 0]

(******************************************************************************)
(* Examples *)
(******************************************************************************)

let ex1 = olam "x" (var "x")
(* Expect [fun x -> x] for [eval ex1] *)

let ex2 = app [olam "x" (var "x"); olam "y" (var "y")]
(* Expect [fun y -> y] for [eval ex2]*)

let ex3 = callback (
            handle (perform "x" (c 0))
            (case_exn "Unhandled_effect" "v" (c 42)
            (case_val "impossible" (var "impossible"))))
(* Expect [42] for [int_state_to_string (eval ex3)] *)

let inc_handler e =
  handle e
  (case_eff "Inc" "v" "k" (continue "k" ((var "v") + (c 1)))
  (case_val "x" (var "x")))

let ex4 = callback (inc_handler (perform "Inc" (c 0)))
(* Expect [1] for [int_state_to_string (eval ex4)] *)

let ex5 = callback (inc_handler (perform "Inc" (c 0) + perform "Inc" (c 1)))
(* Expect [3] for [int_state_to_string (eval ex5)] *)

let ex6 = callback (
            handle (perform "eff" (c 0))
            (case_eff "eff" "v" "k" (discontinue "k" "exn" (c 42))
            ((case_exn "exn" "v'" (var "v'"))
            (case_val "_" (var "_")))))
(* Expect [42] for [int_state_to_string (eval ex6)] *)


let ex7 = handle (c 0)
          (case_eff "eff" "v" "k" (var "v")
          (case_val "v" (var "v")))
(* Expect [exception Stuck] for [eval ex7]. Handlers cannot be installed in C. *)

let ex8 = perform "eff" (c 0)
(* Expect [exception Stuck] for [eval ex8]. Effects cannot be performed in C. *)

let run ?(log=false) () =
  begin match eval ~log ex1 with
  | V (VClos (EAbs (Olam, "x", (EVar "x")), _)), _ -> ()
  | _ -> failwith "ex1 failed"
  end;
  begin match eval ~log ex2 with
  | V (VClos (EAbs (Olam, "y", (EVar "y")), _)), _ -> ()
  | _ -> failwith "ex2 failed"
  end;
  if not (int_state_to_string (eval ~log ex3) = "42") then failwith "ex3 failed";
  if not (int_state_to_string (eval ~log ex4) = "1") then failwith "ex4 failed";
  if not (int_state_to_string (eval ~log ex5) = "3") then failwith "ex5 failed";
  if not (int_state_to_string (eval ~log ex6) = "42") then failwith "ex6 failed";
  try ignore (eval ~log ex7); failwith "ex7 failed" with Stuck -> ();
  try ignore (eval ~log ex8); failwith "ex8 failed" with Stuck -> ()

let _ = run ()
