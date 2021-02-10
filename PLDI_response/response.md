We thank the reviewers for their constructive and high-quality reviews. We shall
take into account all of the minor comments in the final draft.

# Review A

We shall take a close look at the opportunistic optimisation from [24]. We have
experimental support for multi-shot continuations (see supplement). However,
multi-shot continuations currently break compiler optimisations that convert
heap allocations into stack allocation. The details are found in the supplement.
In the future, we plan to fully support multi-shot continuations in Multicore
OCaml.

We shall include the complete results in the evaluation section in the final
draft, so that the distribution of overheads become evident.

# Review B

As the reviewer has rightly suggested, we shall introduce citing [54] in section
1.5. We shall drop the reference to effect system from R4 and retain the
modularity arguments. Section 3 (line 437+) refers to the modularity requirement
and motivates the need for `discontinue` primitive.

Fibers are not necessary for parallelism, which is the main focus of [54].
Effect handlers (supported by fibers in the runtime) bring in native support for
concurrency to OCaml (the focus of this paper). The only reason to discuss
fibers in [54] was to highlight the interaction between the concurrent
mark-and-sweep GC and objects on the fiber stack. Indeed, we plan to retrofit
the OCaml language with parallelism without fibers, and then add fibers+effect
handlers.

The no-effect benchmarks, on which the outliers were reported, ever only have
one fiber. In these benchmarks, the roots on this only fiber stack are marked at
the beginning of the cycle, which is the same as what stock OCaml does. Hence,
the integration of fibers with concurrent mark-and-sweep GC does not contribute
to the observed differences. The observed differences are due to the difference
in the allocator designs between stock and multicore; multicore allocator has
less fragmentation and this leads to differences in the pacing of the
incremental GC.

We shall add comparison to domains (units of parallelism in Multicore OCaml) in
the microbenchmarks.

# Review C

We shall take into account the useful suggestions for improvements to the
introduction. We shall augment the example to better bring out the benefits of
dynamic scoping of handlers. 

As the reviewer has pointed out, the modularity that we refer to is that the
change for asynchronous I/O is localised to the point at which the effect is
performed (`eval`) and where it is handled (`run`), and not the intervening code
(`gsearch`). Modularity ensures that neither the handler in `run` nor the one in
`gsearch` need to be aware of the other (lines 129-131). We shall improve the
presentation here. 

The semantics aims to faithfully model the implementation modulo the one-shot
continuations and the specialised exception handler in the implementation. The
executable semantics has been useful for quickly prototyping different variants
of the effect handler (deep vs shallow, or making both available).

> MAP_GROWSDOWN

XXX TODO

> Relation to aspect-oriented programming

Kammar et al. "Handlers in Action", ICFP 13, makes connections between effect
handlers and aspect-oriented programming. 

> line 291: "For external functions which allocate in the OCaml heap" -- how
  does the compiler know whether a native callee does or doesn't allocate?

Non-allocating external functions may optionally be annotated by the programmer.

> line 313: "In order to forward exceptions..." -- perhaps a silly question but
why is forwarding necessary? Also, can C frames install exception handlers?

C frames cannot install exception handlers, but there may be exception handlers
in the outer OCaml frames to which the exception must be forwarded.

> (This is for me one of the weaker points of the design... are finalisers
  *that* expensive? Is there experimental data on that?)

Thanks for this suggestion. We shall include a thorough evaluation of the
overheads of installing a finaliser for every captured continuation on the micro
and macro benchmarks.
