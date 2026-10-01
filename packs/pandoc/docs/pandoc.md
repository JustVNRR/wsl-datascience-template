# Pandoc & PDF

[← Back to the README](../../../README.md#optional-tooling)

Pandoc and a LaTeX engine, installed by the `pandoc` pack and removed with it,
plus seven targets: `gmake pdf_from_md` and `gmake docx_from_md` turn the
project's markdown into a PDF or a Word file, `gmake pdf_open` displays the
result, `gmake csl_from_catalog` fetches a citation style, and the three
`font_from_*` bring a font family — from Windows, Google Fonts or Ubuntu.

## What it brings

| Piece | For | Commands |
| :--- | :--- | :--- |
| Pandoc | converting markdown; `--citeproc` handles the bibliography | `pandoc` |
| XeLaTeX | the PDF engine a template with its own fonts asks for | `xelatex` |
| PDF tools | checking and assembling the results | `pdftotext`, `pdfinfo`, `pdftoppm`, `pdfunite` |
| Arial | the font the templates ask for, copied from Windows | — |

Pandoc and the engine arrive as Debian packages, a LaTeX distribution being most
of the weight. Arial is not a package: Linux has no Arial, and **fontconfig
aliases do not work with XeTeX** — with an alias in place, `fc-match` resolves
Arial while XeLaTeX still stops on `The font Arial cannot be found`. The fonts
come from `C:\Windows\Fonts` into `~/.local/share/fonts/ms-arial`, and a
removal takes that copy back.

## Installing and removing it

```powershell
.\wsl.ps1 add_pack      # pick the instance, then pandoc
.\wsl.ps1 remove_pack   # the reverse
```

## The targets

From the root of a project under `~/projects`:

```bash
gmake pdf_from_md                            # the folder's markdown -> the PDF beside it
gmake pdf_from_md PDF_SRC=rapport.md         # a document of several, named
gmake pdf_from_md PDF_SRC=rapport.md PDF_OUT=rapport-rv.pdf
gmake pdf_open                               # open the PDF that pdf_from_md built
gmake docx_from_md                           # the same markdown, in Word
gmake csl_from_catalog                       # fetch a citation style from the catalog (menu, or STYLE=name)
```

The names say where they start: these targets are good at **markdown** — its
YAML header carries the bibliography and the citation style, and a LaTeX
template shapes the PDF. Pandoc reads other formats (docx, html, LaTeX), and
the day one of them is wanted, it is another target, named for it.

The three `font_from_*` run from **anywhere** — they install a font for the
machine, not for a project.

A build that would **replace** an existing PDF or Word file asks first, in a
menu: `overwrite`, `cancel`, `save as...` — the last one asks for the name.
Escape is a cancel like any other. With no terminal to draw the menu on — a
script, a pipe — the build **replaces**, and `PDF_OUT` or `DOCX_OUT` is how a
caller says where to write instead.

`pdf_open` opens a **built PDF**, and asks which one from the PDFs themselves:
`PDF_OUT` when the project names it, the PDF of `PDF_SRC` when the source is
named, and otherwise the folder's own `.pdf` files — one of them, or a menu
when there are several, and a line saying there is none. It installs no
viewer, deliberately: it takes the first one the instance has — `evince`,
`zathura`, `xpdf`, `okular`, `mupdf` — or `PDF_VIEWER` when one is named, and
falls back to the Windows default application through `explorer.exe` when the
instance can reach it. Removing a viewer from the machine, or adding one,
changes what it does without anything to configure.

The Word file needs no Word — a `.docx` is an archive of XML, and pandoc
writes it itself. Its look does not come from the LaTeX template (that one
shapes the PDF): it comes from a **reference document**, a `.docx` of your own
whose styles pandoc copies — `DOCX_REFERENCE` names it. Without one, pandoc's
own styles.

| Variable | Default | What it is |
| :--- | :--- | :--- |
| `PDF_SRC` | the folder decides | the markdown to build: the only `.md` of the project, or the one the menu offers when there are several. Named — in the command or in the `.env` — it skips the menu, and that is the form a script calls |
| `PDF_OUT` | `PDF_SRC` with `.pdf` | what to write — and, when it is set, the PDF `pdf_open` opens |
| `PDF_TEMPLATE` | `template.tex` when it is there, pandoc's own template otherwise | the template that gives the PDF its look |
| `PDF_VIEWER` | the first viewer installed | what `pdf_open` runs — `evince`, `zathura`, `xpdf`… `sudo apt install evince` is one command away |
| `DOCX_OUT` | `PDF_OUT` with `.docx` | where the Word file lands |
| `DOCX_REFERENCE` | pandoc's own styles | the `.docx` whose styles the Word file inherits |
| `STYLE` | a menu over the catalog | what `csl_from_catalog` fetches — the name zotero.org/styles shows (`ieee`, `vancouver`…) |
| `FONT` | a menu over the catalogue of the target that runs | the family a `font_from_*` takes; a part of the name is enough |

The menus are `fzf`, and `fzf` needs a terminal: called from a script or a pipe, name the file instead.

A project fixes its own once, in its `.env`: `gmake env_project_enable` appends the pack's sample (the lines are commented out — uncomment what the project needs).

## Bringing a style or a font

A `.csl` is the file that tells pandoc how citations are written and how the
bibliography is ordered — numbers or author-year, superscript or not. A style
belongs to the document, which is why the pack ships none: `gmake
csl_from_catalog` fetches one from the official catalog and drops it in the
project's `csl/` folder, and the YAML header names it with that path
(`csl: csl/<name>.csl`).

A font cannot be aliased into place (XeLaTeX ignores fontconfig
substitutions), so the files themselves are what arrive, and a template only
asks for the family's name. Four ways to one:

| Source | Target | What it brings |
| :--- | :--- | :--- |
| The Windows side | `font_from_windows` | the fonts this machine already owns — Arial came with the install |
| Google Fonts | `font_from_google` | ~1 800 free families, into `~/.local/share/fonts/google/<family>/` |
| The Ubuntu archive | `font_from_ubuntu` | ~200 `fonts-` packages, installed by apt |
| Anywhere | — | a `.ttf` dropped into `~/.local/share/fonts/` is one `fc-cache -f` away |

The first two copy into `~/.local/share/fonts/`, the third installs a package
(`/usr/share/fonts/`) — none of them is the pack's, and removing the pack
leaves them where they are.

A font that must travel **with the project** goes in it, and the template
names the file: `\setmainfont{arial.ttf}[Path=fonts/]`. The pack installs a
family once, for the machine, and leaves the templates as they are
(`\setmainfont{Arial}`).

## What the document carries

The pack touches no document. The bibliography, the citation style and the
template are the document's own: the target passes `--citeproc`, and pandoc
reads the rest from the YAML header.

```yaml
---
bibliography: bibliographie.bib
csl: csl/vancouver-superscript.csl
citeproc: true
---
```

`csl:` names a file — the path is written out, so the styles live in a `csl/`
folder beside the document and the root keeps its markdown, `.bib`, template
and images. A style is not fetched from anywhere at build time: it travels
with the source.

## The commands behind the targets

```bash
pandoc rapport.md --citeproc --template=template.tex -o rapport.pdf --pdf-engine=xelatex
pandoc rapport.md --citeproc -o rapport.docx
```

Any of pandoc's other outputs is one flag away, with no LaTeX involved:
`-o rapport.html`, `-o rapport.epub`.

## When the build stops

| Message | What it means |
| :--- | :--- |
| `No markdown files found in the current folder.` | there is nothing to build here — run it from the folder that holds the `.md` |
| `No PDF in this folder - gmake pdf_from_md builds one.` | `pdf_open` found no `.pdf` here |
| `File <name>.csl not found in resource path` | the CSL style named in the YAML is not beside the document |
| `Unable to load picture or PDF file '<name>'` | an image the document calls is missing |
| `The font Arial cannot be found` | the Arial copy is absent — `.\wsl.ps1 add_pack` again, and see `/mnt/c/Windows/Fonts` |
| `Something's wrong--perhaps a missing \item`, at `\end{CSLReferences}` | the template's `$if(csl-refs)$` block is from an older pandoc: `pandoc -D latex` prints the block of the installed one |

Nothing is cached between runs: a rebuild takes as long as the first build.
