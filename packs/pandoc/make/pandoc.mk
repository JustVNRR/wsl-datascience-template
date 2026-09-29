# ==============================================================================
# THE PDF, WORD, STYLE AND FONT TARGETS (PANDOC)
# ==============================================================================
# What this pack adds, five targets. `pdf`, `pdf_open` and `docx` work on the
# project's document - one resolution for the three, in bin/document.sh, where
# the menu, the build and the viewer live: a recipe that opened a menu itself
# is a recipe nobody can read. `csl_get` and `font_get` bring something a
# document can need - a citation style from the official catalog, a font
# family from the Windows side - and their scripts are neighbours of the
# first.
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
#   STYLE           the citation style csl_get fetches, by the name the
#                   catalog shows (zotero.org/styles). Default: a menu over
#                   the official catalog.
#   FONT            the font family font_get copies; a part of the name is
#                   enough. Default: a menu over the families of the Windows
#                   side.
#
# A project fixes its own once, in its .env - `gmake env_project_enable`
# appends this pack's sample - and the command line still wins over it.

PDF_TEMPLATE ?= template.tex

# The scripts, resolved from this module's own path: make/ and bin/ are
# neighbours inside the pack folder, and the pack moves as one folder.
#
# Named after their TARGETS, never after the tool: a variable called FONT
# would collide with the FONT a person sets - the family font_get copies - and
# the socle's bare `export` would hand the script its own path as a family
# name. Measured, 2026-09-29: the error read "no font family on the Windows
# side matches '/root/.config/packs/pandoc/make/../bin/font.sh'".
DOCUMENT := $(dir $(lastword $(MAKEFILE_LIST)))../bin/document.sh
CSL_GET := $(dir $(lastword $(MAKEFILE_LIST)))../bin/csl.sh
FONT_GET := $(dir $(lastword $(MAKEFILE_LIST)))../bin/font.sh

pdf: ## Build the project's markdown into a PDF (pandoc + XeLaTeX)
	@$(DOCUMENT)

pdf_open: ## Open the built PDF (the first viewer installed, or the Windows default app)
	@$(DOCUMENT) open

docx: ## Build the same document in Word format (.docx) - Word is not needed
	@$(DOCUMENT) docx

csl_get: ## Fetch a citation style from the official CSL catalog, into this project
	@$(CSL_GET)

font_get: ## Copy a font family from the Windows side (Arial came with the install)
	@$(FONT_GET)
