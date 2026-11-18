MD = informe.md
INF_PDF = informe.pdf

.PHONY: informe check

informe: $(INF_PDF)

$(INF_PDF): $(MD)
	TEXINPUTS=../informe/iflatex: pandoc $(MD) -o $(INF_PDF) --pdf-engine=pdflatex -V documentclass=ifreport

check:
	test -f $(INF_PDF)
