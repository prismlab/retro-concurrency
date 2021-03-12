# Review B

We shall add comparison to domains (units of parallelism in Multicore OCaml) in
the microbenchmarks.

# Review C

> (This is for me one of the weaker points of the design... are finalisers
  *that* expensive? Is there experimental data on that?)

Thanks for this suggestion. As other reviewers have pointed out, this is one of
the weaknesses of our solution. We shall include a thorough evaluation of the
overheads of installing a finaliser for every captured continuation on the micro
and macro benchmarks to justify our trade off.
