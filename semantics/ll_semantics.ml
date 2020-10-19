type lam_kind = Clam | Olam

type exp =
  | EConst : int -> exp
  | EVar : string -> exp
  | EApp : exp * exp -> exp
  | EAbs : lam_kind * string * exp -> exp
  | EArith : (int->int->int) * exp * exp -> exp
  | EHandle : exp * handler -> exp
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

and handler_closure = handler * env * fiber option ref

and fiber = F : frame list * handler_closure -> fiber

and continuation = fiber option ref

type ostack =
  | OS: fiber ref * cstack -> ostack

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

let step0 t fs =
  match t,fs with
  (* Constant *)
  | E (EConst n, r), fs -> Some (V (VInt n), fs)

  (* Variable *)
  | E (EVar x, r), fs ->
      begin match r x with
      | None -> raise Stuck (* unbound variable; open term? *)
      | Some v -> Some (V v, fs)
      end

  (* Arithmetic *)
  | E (EArith (f, e1, e2), r), fs -> Some (E (e1, r), FArith1 (f, e2, r)::fs)
  | V (VInt n1), FArith1 (f, e2, r2)::fs -> Some (E (e2, r2), FArith2(f,n1)::fs)
  | V (VInt n2), FArith2 (f, n1)::fs -> Some (V (VInt (f n1 n2)), fs)

  (* Function Application *)
  | E (EApp (f, x), r), fs -> Some (E (f, r), FArg (x, r)::fs)
  | E (EAbs (k, x, e), r), fs -> Some (V (VClos (EAbs (k, x, e), r)), fs)
  | V (VClos (e, v)), FArg (x, r2)::fs -> Some (E (x, r2), FFun (VClos (e, v))::fs)

  (* Continuation resumption *)
  | V (VCont k), FArg (e1, r1)::FArg (e2, r2)::fs ->
      Some (E (e1, r1), FFun (VCont k)::FArg (e2, r2)::fs)
  | V (VClos (e1, r1)), FFun (VCont k)::FArg (e2, r2)::fs ->
      Some (E (e2, r2), FFun (VCont k)::FFun(VClos (e1, r1))::fs)

  (* Raise exception *)
  | E (ERaise (l, e), r), fs -> Some (E (e, r), FFun (VExn l)::fs)

  | _ -> None

let rec appf f1 f2 =
  let F (_,(_,_,r)) = f1 in
  match !r with
  | None -> r := Some f2
  | Some f1 -> appf f1 f2

let ostep t (fr: fiber ref) cs =
  match t, !fr with
  (* Return *)
  | V v, F ([],(h,_,{contents = None})) -> (* Return from OCaml to C *)
      assert (match h with HValue _ -> true | _ -> false);
      Some (V v, C cs)
  | V v, F ([],(h, r, {contents = Some fr'})) ->  (* Handler value return case *)
      let x,e = get_return_case h in
      Some (E (e, extend_env r x v), O (OS (ref fr', cs)))

  (* Function Application *)
  | V v, F (FFun (VClos (EAbs (Olam, x, e), r))::fs,hc) ->
      fr := F (fs, hc);
      Some (E (e, extend_env r x v), O (OS (fr, cs)))
  | V v, F (FFun (VClos (EAbs (Clam, x, e), r))::fs,hc) -> (* External call *)
      fr := F (fs,hc);
      Some (E (e, extend_env r x v), C (CS ([], Some (OS (fr, cs)))))

  (* Continuation resumption *)
  | V v, F (FFun (VCont k)::FFun(VClos (EAbs (Olam, x, e), r))::fs,hc) ->
      begin match !k with
      | None ->
          fr := F (fs, hc);
          Some (E (ERaise ("Continuation_taken", EConst 0), empty_env), O (OS (fr, cs)))
      | Some f ->
          k := None;
          appf f (F (fs,hc));
          Some (E (e, extend_env r x v), O (OS (ref f, cs)))
      end

  (* Install handler *)
  | E (EHandle (e, h), r), f ->
      let fr' = F ([], (h,r,ref (Some f))) in
      Some (E (e, r), O (OS (ref fr', cs)))

  (* Perform operation *)
  | E (EPerform (l, e), r), (F (fs,hc) as f) ->
      fr := F (FFun (VEff (l, ref (Some f)))::fs, hc);
      Some (E (e, r), O (OS (fr, cs)))
  | V v, F (FFun(VEff (l, k))::fs,(h,r,{contents= None} as hc)) ->
      (* Outermost handler has only the value case *)
      let f = match !k with Some f -> f | None -> raise Stuck in
      k := None;
      Some (E (ERaise ("Unhandled_effect", EConst 0), empty_env), O (OS (ref f, cs)))
  | V v, F (FFun (VEff (l, k))::fs,((h,r,rr) as hc)) ->
      let fs',hc' = match !rr with
      | None -> raise Stuck
      | Some (F (fs', hc')) -> fs',hc'
      in
      let f = match !k with Some f -> f | None -> raise Stuck in
      begin match get_effect_case h l with
      | Some (x,kv,e) ->
          rr := None;
          let new_r = extend_env (extend_env r kv (VCont k)) x v in
          Some (E (e, new_r), O (OS (ref (F (fs',hc')), cs)))
      | None ->
          Some (V v, O (OS ( ref (F (FFun (VEff (l, k ))::fs',hc')), cs)))
      end

   (* Raise exception *)
   | V v, F (FFun (VExn l)::fs,(_,_,{contents = None})) ->
      (* Outermost handler has only the value case *)
      let CS (fs,osopt) = cs in
      Some (V v, C (CS (FFun (VExn l)::fs, osopt)))
   | V v, F (FFun (VExn l)::fs,(h,r,{contents = Some (F (fs',hc'))})) ->
       begin match get_exn_case h l with
       | Some (x,e) ->
           let new_r = extend_env r x v in
           Some (E (e, new_r), O (OS (ref (F (fs',hc')), cs)))
       | None ->
           Some (V v, O (OS (ref (F (FFun (VExn l)::fs',hc')), cs)))
       end

  (* Other local operations *)
  | _, F (fs,h) ->
      begin match step0 t fs with
      | Some (t',fs') -> Some (t',O (OS (ref (F (fs',h)), cs)))
      | None -> raise Stuck (* No further reduction *)
      end

let cstep t fs osopt =
  match t, fs with
  (* Return value from C to OCaml *)
  | V v, [] ->
      begin match osopt with
      | None -> None
      | Some os -> Some (V v, O os)
      end

  (* Function Application *)
  | V v, FFun (VClos (EAbs (Olam, x, e), r2))::fs -> (* callback *)
      let hc = HValue ("x", EVar "x"), empty_env, ref None in
      Some (E (e, extend_env r2 x v), O (OS (ref (F ([],hc)), CS (fs, osopt))))
  | V v, FFun (VClos (EAbs (Clam, x, e), r2))::fs ->
      Some (E (e, extend_env r2 x v), C (CS (fs, osopt)))

  (* Raise exception *)
  | V v, FFun (VExn l)::fs ->
      begin match osopt with
      | Some (OS ({contents = F (fs',hc')} as fr, cs)) ->
          fr := F (FFun (VExn l)::fs',hc');
          Some (V v, O (OS (fr, cs)))
      | _ -> (* no handler *)
          print_string ("Unhandled exception: " ^ l ^ "\n");
          raise Stuck
      end

  (* Other local operations *)
  | _, fs ->
      begin match step0 t fs with
      | Some (t',fs') -> Some (t', C (CS (fs', osopt)))
      | None -> raise Stuck (* No further reduction *)
      end

let step (term,stack) =
  match stack with
  | O (OS (k, cs)) -> ostep term k cs
  | C (CS (fs, osopt)) -> cstep term fs osopt

let s st = match step st with
           | None -> failwith "unexpected"
           | Some st -> st

let rec eval_st s =
  match step s with
  | None -> s
  | Some s' -> eval_st s'

let init e = E (e, empty_env), C (CS ([], None))

let eval e = eval_st (init e)

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

let handle e h = EHandle (e, h)

let raise_ l e = ERaise (l, e)

let continue k e = app [var k; olam "x" (var "x"); e]

let discontinue k l e = app [var k; olam "x" (raise_ l (var "x")); e]

let int_state_to_string s =
  match s with
  | V (VInt n), _ -> string_of_int n
  | _ -> "unexpected state"

let (+) e1 e2 = EArith (Stdlib.(+), e1, e2)

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

let ex9 = callback (
            handle (
              handle (perform "eff" (c 0))
              (case_eff "eff" "v" "k" (continue "k" (var "v") + continue "k" (var "v"))
              (case_val "impossible" (var "impossible"))))
            (case_exn "Continuation_taken" "v" (c 42)
            (case_val "impossible" (var "impossible"))))

let run () =
  begin match eval ex1 with
  | V (VClos (EAbs (Olam, "x", (EVar "x")), _)), _ -> ()
  | _ -> failwith "ex1 failed"
  end;
  begin match eval ex2 with
  | V (VClos (EAbs (Olam, "y", (EVar "y")), _)), _ -> ()
  | _ -> failwith "ex2 failed"
  end;
  if not (int_state_to_string (eval ex3) = "42") then failwith "ex3 failed";
  if not (int_state_to_string (eval ex4) = "1") then failwith "ex4 failed";
  if not (int_state_to_string (eval ex5) = "3") then failwith "ex5 failed";
  if not (int_state_to_string (eval ex6) = "42") then failwith "ex6 failed";
  try ignore (eval ex7); failwith "ex7 failed" with Stuck -> ();
  try ignore (eval ex8); failwith "ex8 failed" with Stuck -> ();
  if not (int_state_to_string (eval ex9) = "42") then failwith "ex9 failed"
