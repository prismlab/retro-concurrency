all:
	jupyter nbconvert --execute --to html 'Parsing benchmarks output.ipynb'
	pdfcrop throughput.pdf
	mv throughput-crop.pdf throughput.pdf
	pdfcrop latency.pdf
	mv latency-crop.pdf latency.pdf
