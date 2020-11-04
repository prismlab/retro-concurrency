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

EXE = $(PREFIX)_extcall.exe $(PREFIX)_callback.exe \
	$(PREFIX)_exn_val.exe $(PREFIX)_exn_raise.exe \
	$(PREFIX)_rec_seq_tak.exe $(PREFIX)_rec_seq_fib.exe \
	$(PREFIX)_rec_seq_motzkin.exe $(PREFIX)_rec_seq_ack.exe \
	$(PREFIX)_rec_seq_sudan.exe $(PREFIX)_rec_seq_evenodd.exe

ifneq ($(PREFIX),stock)
	EXE += $(PREFIX)_rec_eff_tak.exe $(PREFIX)_rec_eff_fib.exe \
				 $(PREFIX)_rec_eff_motzkin.exe $(PREFIX)_rec_eff_ack.exe \
				$(PREFIX)_rec_eff_sudan.exe $(PREFIX)_rec_eff_evenodd.exe
endif

bench: all
	taskset --cpu-list 2-10 hyperfine -u millisecond --export-json \
		$(PREFIX).bench --warmup 3 \
		'./$(PREFIX)_extcall.exe 100_000_000' \
		'./$(PREFIX)_callback.exe 100_000_000' \
		'./$(PREFIX)_exn_val.exe 100_100_000' \
		'./$(PREFIX)_exn_raise.exe 100_100_000' \
		'./$(PREFIX)_rec_seq_tak.exe 1 40 20 11' \
		'./$(PREFIX)_rec_seq_fib.exe 4 40' \
		'./$(PREFIX)_rec_seq_sudan.exe 10_000_000 2 2 2' \
		'./$(PREFIX)_rec_seq_motzkin.exe 4 21' \
		'./$(PREFIX)_rec_seq_evenodd.exe 2 500_000_000' \
		'./$(PREFIX)_rec_seq_ack.exe 2 3 11'

all: $(EXE)

$(PREFIX)_extcall.exe: extcall.ml extcall_.c
	$(OCAMLOPT) -o $@ $^

$(PREFIX)_callback.exe: callback.ml callback_.c
	$(OCAMLOPT) -o $@ $^

$(PREFIX)_%.exe: %.ml
	$(OCAMLOPT) -o $@ $^

clean:
	rm -f *.cmo *.cmx *.cmi *.exe *.o *~ a.out perf.* *.s
