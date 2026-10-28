MD = hola-mundo.md
PDF = hola-mundo.pdf
INF_MD = informe.md
INF_PDF = informe.pdf

.PHONY: pdf check informe

informe: $(INF_PDF)

$(INF_PDF): $(INF_MD)
	TEXINPUTS=./iflatex: pandoc $(INF_MD) -o $(INF_PDF) --pdf-engine=pdflatex -V documentclass=ifreport

pdf: $(PDF)

$(PDF): $(MD)
	TEXINPUTS=./iflatex: pandoc $(MD) -o $(PDF) --pdf-engine=pdflatex -V documentclass=ifreport

check:
	test -f $(PDF)
