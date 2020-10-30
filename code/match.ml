effect E : string -> int
effect F : float -> int
let r = match perform (E "42") with
| v -> v == 0
| effect (E s) k -> not (continue k (int_of_string s))
| effect (F f) k -> not (continue k (int_of_float f))
