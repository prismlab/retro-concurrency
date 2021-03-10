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

retro-concurrency-sources.zip:
	mkdir -p retro-concurrency-sources
	cp -r figures results acmart.cls ACM-Reference-Format.bst retro-concurrency.bib \
		retro-concurrency.tex Makefile retro-concurrency-sources
	zip -r retro-concurrency-sources.zip retro-concurrency-sources

all: techrep retro-concurrency-sources.zip

clean:
	make -C bench clean
	make -C code clean
	rm -rf *.log *.aux *.bbl *.blg *~ *.out techrep retro-concurrency-sources \
		retro-concurrency-sources.zip
