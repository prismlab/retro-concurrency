let n = try int_of_string (Sys.argv.(1)) with _ -> 1_000_000

exception E

let rec loop n =
  try () with E -> ()

let _ = loop n
