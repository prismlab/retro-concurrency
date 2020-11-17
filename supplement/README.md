# Supplementary material for PLDI2020 submission Retrofitting Effect Handlers onto OCaml

## Semantics

The executable version of the dynamic semantics is available in `semantics.ml`.
The examples can be run by loading the program in the OCaml interative top-level
`ocaml` or `utop`.

```bash
$ utop
utop # #use "semantics.ml"
```

## Generator from iterator

The code for deriving generator from iterator using effect handlers is available
in [generator.ml].
