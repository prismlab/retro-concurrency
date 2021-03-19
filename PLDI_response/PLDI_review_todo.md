Review #82C
===========================================================================

Overall merit
-------------
B. I support accepting this paper but will not champion it.

Reviewer expertise
------------------
Y. **Knowledgeable** = "I follow the literature on this paper's topic(s)
   but may have missed some relevant developments"

Paper summary
-------------
This paper presents an implementation case study of how Multicore OCaml has
retrofitted a form of algebraic effects into the OCaml language's mainline
implementation. It addresses performance expectations, FFI compatibility and
tool compatibility (playing special attention to DWARF-based unwinders). The
bulk of the contribution is on these implementation concerns, but there is also
a detailed operational semantics for the combined core-plus-FFI languages which
models the chosen implementation's stack management protocols. Performance
experiments on a mixture of micro- and macro(-ish)-benchmarks show that the
overhead is very small indeed when the new features are not used, and overall
competitive when used -- including outperforming pre-existing approaches to
asynchronous I/O, a key use case of effect handling.

Comments for author
-------------------
I enjoyed this paper, despite not being especially familiar with algebraic
effects. (My expertise is patchy; Y should be considered an average of X and Z.)

Although it is a case study, there is quite a lot of reusable knowledge in this
paper. It is particularly heartening to see a strong concern for compatibility
in general and for tool compatibility in particular, since not all
implementation efforts go to such lengths.

The design discussion was generally clear and well-reasoned. See below for a
tiny comment/question about the choice of explicitly grown/checked stack
segments versus a more C-like approach.

I thought the experiments were well-chosen, thorough and generally reported
carefully. It was a bit disappointing not to see even a brief/partial
table/graph summarising of the (non-micro) benchmark results in the main body of
the paper, especially as the text doesn't say much about the variance. I know
there's a lot of them, so this is likely fixable for a hypothetical final paper.

The formal semantics is great to have... even if perhaps a little tacked-on, in
that in my view the paper could stand without it. So what follows is definitely
not a criticism, but I was wondering how well it has been cross-validated
against the main implementation. It's great that it is executable... I was just
wondering generally about its maturity and any uses to which it's been put.

The writing is overall commendably clear and precise... well done.

For me the biggest weaknesses are in the title and first page. The phrase
"effect handlers" seems poorly chosen. A much improved small tweak might be
"effect handling", just as one usually says 'exception handling' not 'exception
handlers'.

The first page doesn't choose particularly good examples: the first paragraph of
the introduction puzzled me because the 'effect' construct shown is not a
handler at all. We don't see a handler per se until line 94. Missing is a clear
statement of (something like) how effect handlers can be considered as a
generalization of the exception handling mechanism, to allow saving a
continuation at the raise site, which is resumed when the handler returns.

Still in the Introduction, lines 37--38: made more sense later but initially
"interpret Read differently" threw me... "handle Read differently" would have
seemed more natural. Much of the Introduction is spent omitting to explain the
key point of why effect handling is different from vanilla higher-order
programming. In the example given, one could simply thread through a function to
call where 'performing an effect' is desired. To really explain algebraic
effects [as I understood them from later on in the paper], this should
explicitly refer to the dynamic nesting of handlers, by analogy with exception
handling. In retrospect, section 1.1 alludes to this, but it could be much more
direct. In particular, the rhetorical question at the end of its first paragraph
can still obviously be answered by "pass in a function".

The issues around modularity are also not very clear here. The type 'val' has
anticipated a fixed set of possible outcomes (infinity, an error value), and the
body of the evaluator knows about 'val'. So this doesn't seem to demonstrate the
"without knowing" property mentioned earlier. I did eventually understood what
was meant (see more comments below) but overall a rewrite of this part seems in
order.

Detailed comments:

line 112: continuing the 'modularity' nitpick: "modularly" in what sense? We've
modified the eval function and its caller -- or in the 'gsearch' example, its
caller's caller. In hindsight the "caller's caller" point seems to be the key
benefit here. With plain old higher-order functions we'd have to thread this
through all intervening functions. Just to throw the modularity cat among the
pigeons: what's the similarity between algebraic effects and the 'explicit join
points' variant of aspect-oriented programming? Such a discussion is
out-of-scope for this paper, but it would be fun to read about this somewhere.
Features that "delocalise" module connections are useful for avoiding
modifications, but can harm modularity in the sense of complicating the
relationships between modules. (Friedrich Steimann's essay from some years back,
"The paradoxical success of aspect-oriented programming", covered some of this
if I recall.)

lines 124-125: probably I'm dense but the functions could have better names.
"Registering an input line" doesn't mean much to me, and what does "get_ui_k"
mean?

lines 147: "direct-style" -- as a noun this should be "direct style". I can
guess what it means ("without callbacks"), but is there a reference for this?

line 163: I wouldn't say stack unwinding is "meaningless" under CPS, only that
there is no *explicit* stack. There is still a callchain, i.e. a linked
collection of not-yet-returned function activations, even if it lives on the
heap. You could probably even write some hairy DWARF metadata that could walk
such a stack.

line 182: "well-behaved" is a bit vague. Also, maybe say "source program"

line 204: I agree it would be wacky to use MAP_GROWSDOWN for continuation
stacks, but is it definitely infeasible (on platforms where virtual addresses
are plentiful)?

line 225: the concept of "one-shot" continuations needs glossing or referencing
here (it is covered later)

line 291: "For external functions which allocate in the OCaml heap" -- how does
the compiler know whether a native callee does or doesn't allocate?

line 297: about finalizers, is the point that the GC is native code, so *any*
finalizer call is a callback to OCaml? Could be clearer if so.

line 306: "*onto* the stack"

line 313: "In order to forward exceptions..." -- perhaps a silly question but
why is forwarding necessary? Also, can C frames install exception handlers?

line 325: "in the frame containing" -- to avoid ambiguity, use "in the frame
that contain"

line 437: at the end of the previous paragraph I was wondering whether we've
seen the subtlety that was promised at line 418. I later guessed that this is
the "exactly once" property covered around 458. But I may have misunderstood.
Perhaps a minor rewrite around here could clarify.

line 463: the solution of raising Unhandled was a bit of a let-down because
you've already told us about that (line 176). So it seems that you do already
ensure that all functions do return exactly once after all (albeit sometimes
exceptionally with this Unhandled). Perhaps I've misunderstood.

line 524: use of the word "case" threw me. It's a record, not a variant.

line 675: nitpick: here the text starts saying "stack" to mean "stack segment".
If "stack segment" is too long, I think "segment" is better than "stack".

line 709: "later" -- use a forward reference or say "in the next subsection"

line 797 and elsewhere: no hyphen in "at most once". If you want to bracket the
phrase, better to use quotes.

line 824: it's "to overflow" not "to overfly", so surely "overflowed"?

line 962--964: "interpreted on demand for building the stack unwind table":
probably "to build", but also mention that the each block of instructions (FDE)
usually covers only a single function... the point being to *avoid* having to
build the entire table.

line 994: it seems a pity not to allude to the solution proposed in the Bastian
et al paper, which makes unwinding a lot faster.

Review #82D
===========================================================================

Overall merit
-------------
B. I support accepting this paper but will not champion it.

Reviewer expertise
------------------
Z. **Some familiarity** = "I have a passing knowledge of the topic(s) but
   do not follow the relevant literature"

Paper summary
-------------
This paper describes how the authors have added effect handlers to
OCaml in a manner that is fast even at scale, backwards compatible,
compatible with popular tool support for OCaml (stack tracing), and
hopefully also compatible with future directions. This paper is
limited to so called one-shot effect handlers, i.e. a setting where
each effect handler is to be resumed at most once. One of the main
challenges is managing the program stack and maintaining its desirable
properties, including DWARF debugging support. This work is in the
context of Multicore OCaml, as opposed to standard OCaml. A formal
semantics is sketched to describe the behavior of the implementation,
but the formal semantics does not cover the fact that the effect
handlers are one-shot. The paper ends with an evaluation section and a
related work section.

Comments for author
-------------------
I must admit that I am not sufficiently familiar with the concepts and
state-of-the-art to give a good verdict on this paper. However, the
paper comes across as describing a solid contribution: a novel and
challenging effort concerning programming language implementation.

The presentation starts off very gently and gradually describes more
complex concepts. Actually, the later descriptions make me wonder if
the initial example was a bit too simple, since it has no parallelism
or asynchrony.

I did not quite follow the compressed explanation of the formal
semantics, which in the end did not seem to capture one of the vital
restrictions of this work, i.e. the fact that the effect handlers are
one-shot only -- and later in the paper it transpires that to avoid
memory leaks they ought to be used, not at most once, but exactly
once. This was a bit of a disappointment.

It was also a bit disappointing that the main evaluation did not fit
into the paper, but had to be put in the supplementary material. I
really do hope the authors manage to make it part of the paper for a
final version (perhaps one or two pages of extra space are allowed for
the final version?)

Minor:

70-86: I appreciate this example very much. however, I wonder if it's
a bit too simple considering that the paper talks a lot about wanting
to use effects for parallelism and asynchrony. this example doesn't
have any of that.

513-521: I lost track of what's going on here

542: abstraction "/\x. x", umm, shouldn't that be "/\x. e" ?

669: it's unclear how similar or different this is from the abstract
machine semantics of Hillerstrom et al. [29]

793: it's a bit of a disappointment that the semantics fails to
capture the fact that effect handlers are one-shot only -- is it not
the purpose of a formal semantics to show exactly what can and cannot
be done with the implementation?

the Implementation section: it was a bit unclear how much was part of
Multicore OCaml separately from the work described in this paper.

1051: pretty dire numbers for the callback benchmark

1060: it's a pity the results didn't fit in the paper, perhaps they
can be made to fit in a final version, if a page or two of extra space
is given?

1228: the first paragraph of the related work seems like a helpful
summary of what other have done. However, I would have appreciated
already here some hints at in which ways the work of the others is
similar or dissimilar from the work of this paper. the subsequence
paragraphs of the related work do not suffer from this problem.

1314: the last sentence of the paper "We believe that the introduction
of [...], will open OCaml to highly scalable concurrent". on my first
read, I thought you are talking about future work here, but then the
text in [...] is describing work already done in this paper! I suggest
that this sentence is made clearer, e.g. "[54], will open OCaml" -->
"[54], as has been demonstrated in our work, will open OCaml"
