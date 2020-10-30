module type Handler = sig
  type 'a eff
  type ('a,'b) continuation
  type ('a, 'b) handler =
    { ret_case : 'a -> 'b;
      eff_case_1 : 'c. 'c eff -> ('c, 'b)continuation -> 'b;
      eff_case_2 : 'd. 'd eff -> ('d, 'b)continuation -> 'b; }

  val perform : 'a eff -> 'a
  val continue : ('a,'b) continuation -> 'a -> 'b
  val discontinue : ('a,'b) continuation -> exn -> 'b
  val match_ : (unit -> 'a) -> ('a, 'b) handler -> 'b
end
