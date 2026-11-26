PRES_MD = presentacion.md
PRES_PDF = presentacion.pdf

.PHONY: presentacion check

presentacion: $(PRES_PDF)

$(PRES_PDF): $(PRES_MD)
	pandoc $(PRES_MD) -t beamer -o $(PRES_PDF) --pdf-engine=pdflatex \
	  -V theme:Madrid -V aspectratio:169

check:
	test -f $(PRES_PDF)
