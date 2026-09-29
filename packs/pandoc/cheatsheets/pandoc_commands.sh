# ==========================================
# PANDOC / PDF CHEATSHEET
# requires: pandoc
# ==========================================
# Pandoc, the LaTeX engine and the Arial copy the `pandoc` pack installs
# (`.\wsl.ps1 add_pack`), and the one target it adds. The pack is removed the
# same way; its page is packs/pandoc/docs/pandoc.md.
# Offered only while pandoc is installed - the header above is what hides the
# sheet when it was removed by hand.

# --- 1. THE PROJECT TARGET (from the root of a project) ---
gmake pdf                                     # The folder's markdown: the only .md, or the one the menu offers
gmake pdf PDF_SRC=rapport.md                  # Name it directly - no menu, the form scripts use
gmake pdf PDF_SRC=rapport.md PDF_OUT=rapport-rv.pdf   # Write it under another name

# --- 2. WHAT THE DOCUMENT CARRIES (its YAML header) ---
# ---
# bibliography: bibliographie.bib             # the .bib beside the document
# csl: vancouver-superscript.csl              # the style beside it too
# citeproc: true                              # render the citations
# ---

# --- 3. THE COMMAND BEHIND THE TARGET ---
pandoc rapport.md --citeproc --template=template.tex -o rapport.pdf --pdf-engine=xelatex
pandoc rapport.md -o rapport.docx             # The same source, Word output
pandoc --version                              # Which version is installed

# --- 4. WHEN THE BUILD STOPS ---
ls *.md *.bib *.csl                           # What the command needs, beside the document
pandoc -D latex | less                        # The template pandoc ships (for the CSLReferences block)
fc-list Arial                                 # The Windows Arial copy: four faces, or nothing
