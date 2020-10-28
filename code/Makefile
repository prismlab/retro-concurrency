all: calc.exe

meander_.o: meander_.c
	gcc -g -I $(shell opam var lib)/ocaml -c $<

meander.exe: meander_.o meander.ml
	ocamlopt -g -o $@ $^

%.exe: %.ml
	dune build $@

clean:
	dune clean
	rm -f *.o *.cm* *.exe
