line 962--964: "interpreted on demand for building the stack unwind table":
probably "to build", but also mention that the each block of instructions (FDE)
usually covers only a single function... the point being to *avoid* having to
build the entire table.

line 994: it seems a pity not to allude to the solution proposed in the Bastian
et al paper, which makes unwinding a lot faster.

1228: the first paragraph of the related work seems like a helpful
summary of what other have done. However, I would have appreciated
already here some hints at in which ways the work of the others is
similar or dissimilar from the work of this paper. the subsequence
paragraphs of the related work do not suffer from this problem.
