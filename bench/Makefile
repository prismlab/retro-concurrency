# PREFIX argument is necessary
#
# In order to benchmark, do something like
# 	taskset --cpu-list 2-10 hyperfine './mc+noredzone_extcall.exe 100_000_000'

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

all: $(PREFIX)_extcall.exe $(PREFIX)_callback.exe \
	$(PREFIX)_exn_val.exe $(PREFIX)_exn_raise.exe \
	$(PREFIX)_rec_seq_tak.exe $(PREFIX)_rec_seq_fib.exe \
	$(PREFIX)_rec_seq_motzkin.exe $(PREFIX)_rec_seq_ack.exe \
	$(PREFIX)_rec_seq_sudan.exe $(PREFIX)_rec_seq_evenodd.exe

$(PREFIX)_extcall.exe: extcall.ml extcall_.c
	$(OCAMLOPT) -o $@ $^

$(PREFIX)_callback.exe: callback.ml callback_.c
	$(OCAMLOPT) -o $@ $^

$(PREFIX)_%.exe: %.ml
	$(OCAMLOPT) -o $@ $^

clean:
	rm -f *.cmo *.cmx *.cmi *.exe *.o *~ a.out perf.* *.s
