effect E : unit
effect F : unit;;
match (* comp_e *)
  match (* comp_f *) (* 1 *) perform E (* 3 *)
  with v -> v | effect F kf -> continue kf ()
with v -> v | effect E ke -> (* 2 *) continue ke ()
