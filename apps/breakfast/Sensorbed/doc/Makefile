LATEX = latex
SPELL = aspell
TEX = MIB
BIBTEX = bibtex
FIGS=$(wildcard *.fig)
EPSS=$(patsubst %.fig,%.eps,$(FIGS))

%.eps: %.fig
	fig2dev -L eps $^ $@

default: $(TEX).tex $(EPSS)
	$(LATEX) $(TEX); $(BIBTEX) $(TEX); $(LATEX) $(TEX); $(LATEX) $(TEX); dvips -t letter -o $(TEX).ps $(TEX).dvi; ps2pdf $(TEX).ps

view: $(TEX).tex
	$(LATEX) $(TEX); $(BIBTEX) $(TEX); $(LATEX) $(TEX); $(LATEX) $(TEX); dvips -t letter -o $(TEX).ps $(TEX).dvi; ps2pdf $(TEX).ps
	acroread $(TEX).pdf &

clean:
	$(RM) -f *.aux *.blg *.dvi *.log *.toc *.lof *.lot *.cb *.bbl $(TEX).ps \
		$(TEX).pdf *.eps

spotless: clean
	$(RM) -f *.ps *.pdf *~ */*.log */*.bak
