#!/usr/bin/env bash
# ==============================================================================
# THE PANDOC PACK - THE SCRIPTS BEHIND `pdf_from_md`, `pdf_open` AND `docx_from_md`
# ==============================================================================
# The targets call this, one line each: where the questions are asked and the
# work happens lives here - the arrangement the claude and web packs follow,
# and for the same reason: a recipe that opened a menu itself is a recipe
# nobody can read.
#
# Three modes:
#   document.sh          builds the PDF (the `pdf_from_md` target);
#   document.sh open     opens what that build wrote (the `pdf_open` target);
#   document.sh docx     writes the same document in Word format (the
#                        `docx_from_md` target - pandoc writes .docx itself:
#                        no Word, no Office, nothing to install).
# The three resolve the document the same way, in the order the answers are
# tried:
#   - PDF_SRC, when the project's .env or the command line sets it: that one,
#     no question. It is also the only path that works without a terminal,
#     which is what a script - or a test - calls;
#   - the folder's only .md: no question either, the ordinary case;
#   - several: fzf asks which, from the folder's own list - and Escape is a
#     decision, not an error (the claude pack's menus, same terms);
#   - none: one line, and out.
#
# What this prints travels to the terminal the target was run from, inside the
# instance: the ASCII rule of install.sh and remove.sh is about wsl.exe and the
# Windows console, and does not reach a target's output.

set -euo pipefail

# The pack's variables are read from the environment: the socle's Makefile
# exports everything it loaded (the bare `export` above the includes), so
# PDF_SRC, PDF_OUT, PDF_TEMPLATE, PDF_VIEWER, DOCX_OUT and DOCX_REFERENCE
# arrive here already carrying what the .env, the command line and the
# defaults decided - nothing is parsed a second time.
die() {
    printf '%s\n' "$1" >&2
    exit 1
}

MODE=${1:-build}
SRC=""
OUT=""

# --- which document -----------------------------------------------------------

if [ -n "${PDF_SRC:-}" ]; then
    SRC=$PDF_SRC
    [ -f "$SRC" ] || die "PDF_SRC=$SRC: no such file in $(pwd)."
else
    # nullglob, so a folder with no .md at all hands the array nothing rather
    # than the pattern itself.
    shopt -s nullglob
    files=(*.md)
    shopt -u nullglob
    case ${#files[@]} in
    0)
        die "No markdown files found in the current folder."
        ;;
    1)
        SRC=${files[0]}
        ;;
    *)
        # fzf, like every other picker of this shell (fnew, fcheat, the packs'
        # menus). A menu needs a terminal - answered from a pipe or a script it
        # cannot be, and the file is named instead.
        if choice=$(printf '%s\n' "${files[@]}" | fzf --prompt="document > " --info=inline --layout=reverse); then
            [ -n "$choice" ] || die "Nothing chosen."
            SRC=$choice
        else
            status=$?
            # fzf exits 130 on Escape or Ctrl-C: the person said no, which is a
            # decision, not a failure - and make must not print "Error" over it.
            if [ "$status" -eq 130 ]; then
                printf 'Nothing chosen.\n'
                exit 0
            fi
            die "No document chosen - a menu needs a terminal. Name one instead: gmake pdf_from_md PDF_SRC=<file>"
        fi
        ;;
    esac
fi

# --- built where --------------------------------------------------------------

# PDF_OUT, or the source's name with .pdf.
OUT=${PDF_OUT:-}
[ -n "$OUT" ] || OUT=${SRC%.md}.pdf

# --- docx: the same document, in Word -----------------------------------------
#
# A .docx is the Office format - an archive of XML - and pandoc writes it
# itself: no Word, no Office, nothing installed. What the Word file LOOKS like
# is not the LaTeX template's business (that one shapes the PDF): it comes
# from a reference document - a .docx of your own whose styles pandoc copies -
# and DOCX_REFERENCE names it. Without one, pandoc's default styles.
if [ "$MODE" = docx ]; then
    docx_out=${DOCX_OUT:-}
    [ -n "$docx_out" ] || docx_out=${OUT%.pdf}.docx
    REF_ARGS=()
    if [ -n "${DOCX_REFERENCE:-}" ]; then
        [ -f "$DOCX_REFERENCE" ] || die "DOCX_REFERENCE=$DOCX_REFERENCE: no such file in $(pwd)."
        REF_ARGS=(--reference-doc="$DOCX_REFERENCE")
    fi
    echo "📄 Building $SRC -> $docx_out (Word)..."
    pandoc "$SRC" --citeproc "${REF_ARGS[@]}" -o "$docx_out"
    echo "✅ $docx_out ($(du -h "$docx_out" | cut -f1))"
    exit 0
fi

# --- pdf_open: hand it to something that displays it ---------------------------
#
# The pack installs no viewer, and that is deliberate: each is a matter of
# taste and none is required to build, so a pack that forced one would make
# every machine pay for it (measured on the three, 2026-09-29: xpdf 31 MB,
# zathura 170 MB, evince 265 MB). This asks the instance instead, in this
# order:
#   - PDF_VIEWER, when the project's .env or the command line names one - for
#     the person who wants xpdf here and evince there;
#   - the viewers people install by hand, the convivial one first;
#   - Windows, through explorer.exe, when the instance can reach it - the
#     default application for a PDF, and the path travels as Windows knows it
#     (wslpath). With interop off, this door is shut and the line below says
#     what to do instead.
if [ "$MODE" = open ]; then
    [ -f "$OUT" ] || die "$OUT is not built yet - gmake pdf_from_md builds it."
    if [ -n "${PDF_VIEWER:-}" ]; then
        command -v "$PDF_VIEWER" >/dev/null 2>&1 ||
            die "PDF_VIEWER=$PDF_VIEWER: not installed in this instance. Install it, or drop the setting - the viewers are tried in turn without it."
        exec "$PDF_VIEWER" "$OUT"
    fi
    for viewer in evince zathura xpdf okular mupdf; do
        if command -v "$viewer" >/dev/null 2>&1; then
            exec "$viewer" "$OUT"
        fi
    done
    if command -v explorer.exe >/dev/null 2>&1; then
        exec explorer.exe "$(wslpath -w "$OUT")"
    fi
    die "No PDF viewer in this instance, and no way through to Windows.
One command installs one: sudo apt install evince
Or copy it out and open it there: cp $OUT /mnt/d/"
fi

# --- pdf: build it -------------------------------------------------------------

# PDF_TEMPLATE, or template.tex when the project has one - pandoc's own
# template otherwise, and the line says so. An array, not a string: an empty
# variable between two other arguments would vanish into the word split - which
# the linter is right to refuse, the day it is an unquoted flag.
tpl=${PDF_TEMPLATE:-template.tex}
if [ -f "$tpl" ]; then
    TEMPLATE_ARGS=(--template="$tpl")
else
    TEMPLATE_ARGS=()
    printf '   no %s in this project: pandoc own template will be used.\n' "$tpl"
fi

# The command a document's own folder carries:
#   pandoc <src>.md --citeproc [--template=...] -o <out>.pdf --pdf-engine=xelatex
# --citeproc: the bibliography and the CSL style are read from the YAML header
# of the document itself. set -e is on: a build that fails stops here, before
# the tick line - a success line over a failed build is the one lie this script
# could tell.
echo "📄 Building $SRC -> $OUT (pandoc + xelatex)..."
pandoc "$SRC" --citeproc "${TEMPLATE_ARGS[@]}" -o "$OUT" --pdf-engine=xelatex
echo "✅ $OUT ($(du -h "$OUT" | cut -f1))"
