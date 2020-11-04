PREFIX ?=

ifeq ($(PREFIX),stock)
	OCAMLOPT := ocamlopt.opt
else ifeq ($(PREFIX),mc)
	OCAMLOPT := ~/repos/ocaml-multicore/_install/bin/ocamlopt.opt
else ifeq ($(PREFIX),mc+noredzone)
	OCAMLOPT := ~/repos/ocaml-multicore-redzone0/_install/bin/ocamlopt.opt
else
	OCAMLOPT :=
endif

all: $(PREFIX)_extcall.exe

$(PREFIX)_extcall.exe: extcall.ml extcall_.c
	$(OCAMLOPT) -o $@ $^

clean:
	rm -f *.cmo *.cmx *.cmi *.exe *.o *~
