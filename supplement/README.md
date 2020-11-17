# Supplementary material for PLDI2020 submission Retrofitting Effect Handlers onto OCaml

## Semantics

The executable version of the dynamic semantics is available in `semantics.ml`.
The examples can be run by loading the program in the OCaml interative top-level
`ocaml` or `utop`.

```bash
$ utop
utop # #use "semantics.ml"
```

You can also run individual examples with logging turned on which traces the
steps. For example, example `ex3` in `semantics.ml` is the equivalent of the
Multicore OCaml program:

```ocaml
match perform X 0 with
| v -> v
| exception Unhandled _ -> 42
```

This program can be run with logging turned on as follows:

```bash
$ utop
utop # #use "semantics.ml"
utop # eval ~log:true ex3;;
App1 AdminC StepC
App2 AdminC StepC
App3 AdminC StepC
Const AdminC StepC
Callback StepC
Handle StepO
Perform AdminO StepO
Const AdminO StepO
EffFwd StepO
EffUnHn StepO
Raise AdminO StepO
Const AdminO StepO
ExnFwdFib StepO
ExnHn StepO
Const AdminO StepO
RetToC StepO
- : term * stack = (V (VInt 42), C (CS ([], None)))
```

The rules `Const` is not necessary in the semantics in the paper. Otherwise, the
rest of the steps correspond to the semantics in the paper.

## Generator from iterator

The code for deriving generator from iterator using effect handlers is available
in [generator.ml].
