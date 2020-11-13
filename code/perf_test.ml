let n = try int_of_string Sys.argv.(1) with _ -> 30

let rec foo n =
  if n = 0 then ()
  else (foo (n-1); foo (n-1))

let _ = foo n
