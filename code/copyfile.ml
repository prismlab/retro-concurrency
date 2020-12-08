let input_file = try Sys.argv.(1) with _ -> failwith "no input file"
let output_file = try Sys.argv.(2) with _ -> failwith "no output file"

effect E : 'a -> unit

let copy ic oc =
  let rec loop () =
    let l = input_line ic in
    output_string oc (l ^ "\n");
    loop ()
  in
  try loop () with
  | End_of_file  -> close_in ic; close_out oc
  | e -> close_in ic; close_out oc; raise e

let _ = copy (open_in input_file) (open_out output_file)
