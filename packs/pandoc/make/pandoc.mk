# ==============================================================================
# THE PDF (PANDOC + XELATEX)
# ==============================================================================
# The one target this pack adds: `gmake pdf` builds the project's markdown into
# a PDF. It is an ordinary project target - the location gate holds it to the
# root of a project under ~/projects, which is where the documents live.
#
# One line, and the questions live in bin/pdf.sh, where the menu and the
# command are: a recipe that opened a menu itself is a recipe nobody can read.
#
# Three variables, each with a default that covers the ordinary case. They are
# not named on the recipe line: the socle's Makefile exports everything it
# loaded, so the script reads them from the environment, already carrying what
# the project's .env, the command line and the defaults decided.
#
#   PDF_SRC       the markdown to build. Unset - the way the target is usually
#                 called - the choice is made from the folder itself: one .md
#                 builds it, several are offered in a menu, none is said and
#                 out. Named, it skips the menu, and that is the only form that
#                 works without a terminal.
#   PDF_OUT       what to write. Default: PDF_SRC with .pdf.
#   PDF_TEMPLATE  the LaTeX template. Default: template.tex when it is there,
#                 pandoc's own template otherwise.
#
# A project fixes its own once, in its .env - `gmake env_project_enable`
# appends this pack's sample - and the command line still wins over it.

PDF_TEMPLATE ?= template.tex

# The script, resolved from this module's own path: make/ and bin/ are
# neighbours inside the pack folder, and the pack moves as one folder.
PDF := $(dir $(lastword $(MAKEFILE_LIST)))../bin/pdf.sh

pdf: ## Build the project's markdown into a PDF (pandoc + XeLaTeX)
	@$(PDF)
