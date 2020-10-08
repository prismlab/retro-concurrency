OPAMLIB = $(shell opam var lib)

all: utlc.exe

%.ml: %.fst
	echo $(OPAMLIB)
	fstar.exe --codegen OCaml $<

%.exe: %.ml
	ocamlfind ocamlopt -package fstarlib fstarlib.cmxa -o $@ $<

clean:
	rm -f *.ml *.cm* *.o *.exe
