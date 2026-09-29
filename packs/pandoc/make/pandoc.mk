# ==============================================================================
# PDF, WORD, STYLE AND FONT TARGETS (PANDOC)
# ==============================================================================
# What this pack adds, five targets. `pdf_from_md` and `docx_from_md` build the
# project's markdown, and `pdf_open` displays the result - one resolution for
# the three, in bin/document.sh, where the menu, the builds and the viewer
# live: a recipe that opened a menu itself is a recipe nobody can read.
# `csl_from_catalog` and `font_from_windows` bring something a document can
# need - a citation style, a font family - and their scripts are neighbours of
# the first.
#
# The names say where they start. What these targets are good at is markdown:
# the document's YAML header carries the bibliography and the citation style,
# and a LaTeX template shapes the PDF. A target called `pdf` would promise any
# source; the door stays open - pandoc reads docx, html, LaTeX - and the day
# one of those is wanted, it is another target, named for what it takes.
#
# All five are ordinary project targets: the location gate holds them to the
# root of a project under ~/projects, which is where the documents live.
#
# The variables, each with a default that covers the ordinary case. They are
# not named on the recipe lines: the socle's Makefile exports everything it
# loaded, so the scripts read them from the environment, already carrying what
# the project's .env, the command line and the defaults decided.
#
#   PDF_SRC         the markdown to build. Unset - the way the targets are
#                   usually called - the choice is made from the folder
#                   itself: one .md builds it, several are offered in a menu,
#                   none is said and out. Named, it skips the menu, and that
#                   is the only form that works without a terminal.
#   PDF_OUT         the PDF. Default: PDF_SRC with .pdf.
#   PDF_TEMPLATE    the LaTeX template. Default: template.tex when it is
#                   there, pandoc's own template otherwise.
#   PDF_VIEWER      what pdf_open runs. Default: the first viewer installed -
#                   evince, zathura, xpdf, okular, mupdf - and the Windows
#                   default application when there is none and the instance
#                   can reach it.
#   DOCX_OUT        the Word file. Default: the PDF's name with .docx.
#   DOCX_REFERENCE  a .docx of your own whose styles pandoc copies - how the
#                   Word file gets its look. Default: pandoc's own styles.
#   STYLE           the citation style csl_from_catalog fetches, by the name
#                   the catalog shows (zotero.org/styles). Default: a menu
#                   over the official catalog.
#   FONT            the font family font_from_windows copies; a part of the
#                   name is enough. Default: a menu over the families of the
#                   Windows side.
#
# A project fixes its own once, in its .env - `gmake env_project_enable`
# appends this pack's sample - and the command line still wins over it.

PDF_TEMPLATE ?= template.tex

# The scripts, resolved from this module's own path: make/ and bin/ are
# neighbours inside the pack folder, and the pack moves as one folder.
#
# A script variable must never carry the name of something a person sets: a
# variable called FONT once held this path, and the socle's bare `export`
# handed it to the script as the family name to copy - the error quoted the
# path itself ("no font family ... matches '.../bin/font.sh'", measured
# 2026-09-29). DOCUMENT serves the three document targets; the other two are
# named after the target they serve.
DOCUMENT := $(dir $(lastword $(MAKEFILE_LIST)))../bin/document.sh
CSL_FROM_CATALOG := $(dir $(lastword $(MAKEFILE_LIST)))../bin/csl.sh
FONT_FROM_WINDOWS := $(dir $(lastword $(MAKEFILE_LIST)))../bin/font.sh

pdf_from_md: ## Build the project's markdown into a PDF (pandoc + XeLaTeX)
	@$(DOCUMENT)

pdf_open: ## Open the built PDF (the first viewer installed, or the Windows default app)
	@$(DOCUMENT) open

docx_from_md: ## Build the project's markdown in Word format (.docx) - Word is not needed
	@$(DOCUMENT) docx

csl_from_catalog: ## Fetch a citation style from the official CSL catalog, into this project
	@$(CSL_FROM_CATALOG)

font_from_windows: ## Copy a font family from the Windows side (Arial came with the install)
	@$(FONT_FROM_WINDOWS)
