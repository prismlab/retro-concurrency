let input_file = try Sys.argv.(1) with _ -> failwith "no input file"
let output_file = try Sys.argv.(2) with _ -> failwith "no output file"

effect E : 'a -> unit

let rec copy ic oc =
  try
    let l = input_line ic in
    output_string oc (l ^ "\n");
    copy ic oc
  with _ -> (close_in ic; close_out oc)

let _ = copy (open_in input_file) (open_out output_file)
