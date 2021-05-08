paper:
	pdflatex retro-concurrency
	bibtex retro-concurrency
	pdflatex retro-concurrency
	pdflatex retro-concurrency

techrep: paper
	mkdir -p techrep
	pdflatex -output-directory techrep '\def\techreport{1}\input{retro-concurrency}'

haste:
	pdflatex retro-concurrency

retro-concurrency-sources.zip: paper
	mkdir -p retro-concurrency-sources
	mkdir -p retro-concurrency-sources/sandmark-notebook
	mkdir -p retro-concurrency-sources/http-benchmarks
	cp -r figures acmart.cls ACM-Reference-Format.bst retro-concurrency.bib \
		retro-concurrency.tex Makefile unicode-preamble.tex retro-concurrency.bbl \
		retro-concurrency-sources
	cp sandmark-notebook/*.pdf retro-concurrency-sources/sandmark-notebook
	cp http-benchmarks/*.pdf retro-concurrency-sources/http-benchmarks
	zip -r retro-concurrency-sources.zip retro-concurrency-sources

graphs:
	make -C sandmark-notebook
	make -C http-benchmarks

all: techrep retro-concurrency-sources.zip

clean:
	make -C bench clean
	make -C code clean
	rm -rf *.log *.aux *.bbl *.blg *~ *.out techrep retro-concurrency-sources \
		retro-concurrency-sources.zip
