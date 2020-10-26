OPAMLIB = $(shell opam var lib)

all: utlc.exe

%.ml: %.fst
	echo $(OPAMLIB)
	fstar.exe --codegen OCaml $<

%.exe: %.ml
	ocamlfind ocamlopt -package fstarlib fstarlib.cmxa -o $@ $<

clean:
	rm -f *.cm* *.o *.exe
