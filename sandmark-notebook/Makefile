all:
	jupyter nbconvert --execute --to html sequential.ipynb
	pdfcrop sandmark_time.pdf
	mv sandmark_time-crop.pdf sandmark_time.pdf
	pdfcrop sandmark_codesize.pdf
	mv sandmark_codesize-crop.pdf sandmark_codesize.pdf
