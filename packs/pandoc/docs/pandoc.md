# Pandoc & PDF

[← Back to the README](../../../README.md#optional-tooling)

Pandoc and a LaTeX engine, installed by the `pandoc` pack and removed with it,
plus the one target that drives them: `gmake pdf` builds a project's markdown
into a PDF, bibliography included.

## What it brings

| Piece | For | Commands |
| :--- | :--- | :--- |
| Pandoc | converting markdown; `--citeproc` handles the bibliography | `pandoc` |
| XeLaTeX | the PDF engine a template with its own fonts asks for | `xelatex` |
| Arial | the font the templates ask for, copied from Windows | — |

Pandoc and the engine arrive as Debian packages — 88 packages, about 780 MB
installed, a LaTeX distribution being most of it. Arial is not a package: Linux
has no Arial, and **fontconfig aliases do not work with XeTeX** (measured: with
an alias in place, `fc-match` resolves Arial while XeLaTeX still stops on
`The font Arial cannot be found`). The fonts themselves are copied from
`C:\Windows\Fonts` into `~/.local/share/fonts/ms-arial`, and a removal takes
that copy back.

## Installing and removing it

```powershell
.\wsl.ps1 add_pack      # pick the instance, then pandoc
.\wsl.ps1 remove_pack   # the reverse
```

## `gmake pdf`

From the root of a project under `~/projects`:

```bash
gmake pdf                                    # the project's only .md -> the PDF beside it
gmake pdf PDF_SRC=rapport.md                 # when the project holds several .md
gmake pdf PDF_SRC=rapport.md PDF_OUT=rapport-rv.pdf
```

| Variable | Default | What it is |
| :--- | :--- | :--- |
| `PDF_SRC` | the only `.md` of the project | the markdown to build. With several and none named, the target refuses and lists them |
| `PDF_OUT` | `PDF_SRC` with `.pdf` | what to write |
| `PDF_TEMPLATE` | `template.tex` when it is there, pandoc's own template otherwise | the template that gives the document its look |

A project fixes its own once, in its `.env`: `gmake env_project_enable` appends
the pack's sample (the lines are commented out — uncomment what the project
needs).

## What the document carries

The pack touches no document. The bibliography, the citation style and the
template are the document's own: the target passes `--citeproc`, and pandoc
reads the rest from the YAML header.

```yaml
---
bibliography: bibliographie.bib
csl: vancouver-superscript.csl
citeproc: true
---
```

`csl:` names a file beside the document — a style is not fetched from anywhere,
it travels with the source.

## The command behind the target

```bash
pandoc rapport.md --citeproc --template=template.tex -o rapport.pdf --pdf-engine=xelatex
```

Any of pandoc's other outputs is one flag away, with no LaTeX involved:
`-o rapport.docx`, `-o rapport.html`.

## When the build stops

| Message | What it means |
| :--- | :--- |
| `File <name>.csl not found in resource path` | the CSL style named in the YAML is not beside the document |
| `Unable to load picture or PDF file '<name>'` | an image the document calls is missing |
| `The font Arial cannot be found` | the Arial copy is absent — `.\wsl.ps1 add_pack` again, and see `/mnt/c/Windows/Fonts` |
| `Something's wrong--perhaps a missing \item`, at `\end{CSLReferences}` | the template's `$if(csl-refs)$` block is from an older pandoc: `pandoc -D latex` prints the block of the installed one |

A document of about 200 pages with some fifty images takes about forty seconds;
a rebuild takes the same — nothing is cached between runs.
