.PHONY: init
init:
	brew bundle

COVER_LETTERS := $(wildcard cover_letter_*.tex)
COVER_LETTER_PDFS := $(patsubst %.tex,build/pdfs/cover_letters/%.pdf,$(COVER_LETTERS))

.PHONY: build
build:
	rm -rf build
	mkdir -p build/pdfs/cover_letters
	pdflatex -interaction=nonstopmode -halt-on-error -file-line-error -output-directory=build -jobname=ios_resume_abridged ios_resume_abridged.tex
	pdflatex -interaction=nonstopmode -halt-on-error -file-line-error -output-directory=build -jobname=ios_resume ios_resume.tex
	pdflatex -interaction=nonstopmode -halt-on-error -file-line-error -output-directory=build -jobname=cv cv.tex
	mv build/ios_resume_abridged.pdf build/pdfs/ios_resume_abridged.pdf
	mv build/ios_resume.pdf build/pdfs/ios_resume.pdf
	mv build/cv.pdf build/pdfs/cv.pdf
	$(foreach cl,$(COVER_LETTERS),pdflatex -interaction=nonstopmode -halt-on-error -file-line-error -output-directory=build -jobname=$(basename $(cl)) $(cl) && mv build/$(basename $(cl)).pdf build/pdfs/cover_letters/$(basename $(cl)).pdf ;)
