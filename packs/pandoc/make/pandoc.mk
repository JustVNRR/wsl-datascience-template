# ==============================================================================
# THE PDF (PANDOC + XELATEX)
# ==============================================================================
# The one target this pack adds: `gmake pdf` builds the project's markdown into
# a PDF. It is an ordinary project target - the location gate holds it to the
# root of a project under ~/projects, which is where the documents live.
#
# It runs the command a document of this kind carries in its own folder:
#
#   pandoc <source>.md --citeproc --template=template.tex \
#          -o <source>.pdf --pdf-engine=xelatex
#
# The bibliography and the CSL style are not on that line on purpose: pandoc
# reads them from the YAML header of the markdown itself (`bibliography:`,
# `csl:`, `citeproc: true`), which is where the document declares them. The file
# names the style it wants, and a second document can want another one.
#
# Three variables, each with a default that covers the ordinary case. A project
# fixes its own once, in its .env - `gmake env_project_enable` appends this
# pack's sample - and the command line still wins over it:
#
#   PDF_SRC       the markdown to build. Default: the only .md of the project.
#                 With several, the bare call refuses and lists them: building
#                 the wrong document of a set in silence is worse than one more
#                 word on the command line.
#   PDF_OUT       what to write. Default: PDF_SRC with .pdf.
#   PDF_TEMPLATE  the LaTeX template. Default: template.tex when it is there,
#                 pandoc's own template otherwise.

PDF_TEMPLATE ?= template.tex

pdf: ## Build the project's markdown into a PDF (pandoc + XeLaTeX)
	@set -e; \
	src="$(PDF_SRC)"; \
	if [ -z "$$src" ]; then \
		set -- *.md; \
		if [ ! -f "$$1" ]; then \
			echo "❌ No .md file in this project - nothing to build." >&2; \
			exit 1; \
		fi; \
		if [ $$# -gt 1 ]; then \
			echo "❌ Several markdown files here: $$*" >&2; \
			echo "   Name the one to build:  gmake pdf PDF_SRC=<file>" >&2; \
			exit 1; \
		fi; \
		src="$$1"; \
	fi; \
	out="$(PDF_OUT)"; \
	[ -n "$$out" ] || out="$${src%.md}.pdf"; \
	tpl="$(PDF_TEMPLATE)"; \
	if [ -f "$$tpl" ]; then tpl_arg="--template=$$tpl"; else \
		tpl_arg=""; \
		echo "   no $$tpl in this project: pandoc's default template will be used."; \
	fi; \
	echo "📄 Building $$src -> $$out (pandoc + xelatex)..."; \
	pandoc "$$src" --citeproc $$tpl_arg -o "$$out" --pdf-engine=xelatex; \
	echo "✅ $$out ($$(du -h "$$out" | cut -f1))"
