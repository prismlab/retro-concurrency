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

> Relation to aspect-oriented programming

Kammar et al. "Handlers in Action", ICFP 13, makes connections between effect
handlers and aspect-oriented programming.

> Using MAP_GROWSDOWN

The use of mmap with MAP_GROWSDOWN for fibers would mean that the fibers are at
least two 4k pages in size. Currently, our fibers start at 32 words. Secondly,
stack overflow checks are not that expensive (as shown in our results). Last, we
do want effect handlers to be supported on 32-bit platforms where OCaml runs,
even if parallelism may not be supported. Stack switching is portable across the
platforms supported by OCaml. That said, MAP_GROWSDOWN solution may be
appropriate where the stacks cannot be moved (which we understand is the
situation with Web Assembly).

> Relation to aspect-oriented programming

Kammar et al. "Handlers in Action", ICFP 13, makes some connections between
effect handlers and aspect-oriented programming. 

> line 291: "For external functions which allocate in the OCaml heap" -- how
  does the compiler know whether a native callee does or doesn't allocate?

Non-allocating external functions may optionally be annotated by the programmer
as `@noalloc`. The compiler does not ensure that these annotations are correct.

> line 313: "In order to forward exceptions..." -- perhaps a silly question but
why is forwarding necessary? Also, can C frames install exception handlers?

C frames cannot install exception handlers, but there may be exception handlers
in the outer OCaml frames to which the exception must be forwarded.

> (This is for me one of the weaker points of the design... are finalisers
  *that* expensive? Is there experimental data on that?)

Thanks for this suggestion. As other reviewers have pointed out, this is one of
the weaknesses of our solution. We shall include a thorough evaluation of the
overheads of installing a finaliser for every captured continuation on the micro
and macro benchmarks to justify our trade off.

# Review 4

We shall go for a more illustrative example in the introduction (as suggested by
other reviewers as well). We shall add the main results in the body of the paper
for the final version.

Multicore OCaml clearly separates out concurrency from parallelism (running on
2+ cores) using distinct mechanisms to express them -- domains and effect
handlers. We can have one without the other. [54] discusses retrofitting
parallelism to OCaml; fibers are not necessary for parallelism. The focus of
[54] is the concurrent garbage collector. [54] briefly touches upon fibers only
to describe the interaction with the concurrent GC. None of the benchmarks in
[54] use effect handlers. The focus of this paper is retrofitting concurrency to
OCaml. None of the benchmarks in this paper involve parallelism. 

Our aim with the semantics was to formally capture the semantics of stack
manipulation, making explicit the interaction between C and OCaml stacks, which
other presentations typically avoid. We chose not to model one-shot
continuations since they are well understood. In the implementation,
continuations are fresh heap objects that refer to the fiber. This reference
gets overwritten with NULL when a continuation is resumed. Continuation
resumption raises exception when the reference to the fiber in a continuation is
NULL. Modelling this in the semantics would be straight-forward (by adding a
heap to the configuration), but tedious. It does not bring in novel insights but
would obscure the presentation. Hence, we avoided encoding one-shot semantics.

Since the exactly-once use of continuations is an expectation not enforced by
the compiler, the semantics would not change. In the final version, we shall
state upfront (in Section 4.2) that the dynamic semantics aims to model stack
manipulation.

Hillerstrom et al. [29] do not model C and OCaml stacks explicitly. [29] is also
in a setting with an effect system. Hence, programs with unhandled effects would
be statically rejected. In this work, unhandled effects raise exceptions at the
point of perform to clean up resources. [29] models both deep and shallow
handlers. Our handlers are deep. [29] uses fine-grained call-by-value (FGCBV),
but we use call-by-value (CBV). While FGCBV would avoid a few administrative
reduxes by having a separate syntactic category of "interesting" operations, we
chose CBV so that the examples in the executable semantics (see supplement)
remain syntactically similar to their analogues in Multicore OCaml.
