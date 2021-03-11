effect Fork : (unit -> unit) -> unit
effect Yield : unit
effect Read : in_channel -> string

let sync_io main =
  let runq = Queue.create () in
  let suspend k = Queue.push k runq in
  let rec run_next () =
    match Queue.take_opt runq with
    | None -> ()
    | Some k -> continue k ()
  in
  let rec spawn f =
    match f () with
    | () -> run_next ()
    | effect Yield k -> suspend k; run_next ()
    | effect (Fork f) k -> suspend k; spawn f
    | effect (Read ic) k -> continue k (input_line ic)
  in
  spawn main


(* In order to abstract away from the details of the event-loop, we assume the
 * existence of a [do_reads] function, which given a list of pairs of input
 * channels and continuations, and performs the reads using the event-loop. It
 * returns a pair of lists [(done,todo)], where [done] is list of pairs of
 * input strings and corresponding continuations, and [todo] is a list of pairs
 * of input channels on which input is pending and their associated
 * continuations.
 *)
let do_reads (l : (in_channel * (string, unit) continuation) list) :
             (string * (string, unit) continuation) list *
             (in_channel * (string, unit) continuation) list = failwith "not implemented"

let async_io main =
  let runq = Queue.create () in
  let suspend k = Queue.push (continue k) runq in
  let reads = ref [] in
  let rec run_next () =
    match Queue.take_opt runq with
    | None ->
        begin match !reads with
        | [] -> () (* no pending reads *)
        | todo ->
            let (done_,todo) = do_reads todo in
                               (* blocks until one of the reads succeeds *)
            reads := todo;
            List.iter (fun (str,k) ->
              Queue.push (fun () -> continue k str) runq) done_;
            run_next ()
        end
    | Some f -> f ()
  in
  let rec spawn f =
    match f () with
    | () -> run_next ()
    | effect Yield k -> suspend k; run_next ()
    | effect (Fork f) k -> suspend k; spawn f
    | effect (Read ic) k ->
        reads := (ic,k)::!reads;
        run_next ()
  in
  spawn main

let fork f = perform (Fork f)
let yield () = perform Yield
let read ic = perform (Read ic)

let main () =
  fork (fun _ -> print_endline "1.a"; yield (); print_endline "1.b");
  fork (fun _ -> print_endline "2.a"; yield (); print_endline "2.b");
  fork (fun _ -> print_endline (read stdin))

let _ = sync_io main
