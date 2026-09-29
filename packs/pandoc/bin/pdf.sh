#!/usr/bin/env bash
# ==============================================================================
# THE PANDOC PACK - THE `pdf` TARGET'S SCRIPT
# ==============================================================================
# `gmake pdf` calls this, and the recipe is one line: where the questions are
# asked and the command is run lives here - the arrangement the claude and web
# packs follow, and for the same reason: a recipe that opened a menu itself is
# a recipe nobody can read.
#
# The document to build, in the order the answers are tried:
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
# PDF_SRC, PDF_OUT and PDF_TEMPLATE arrive here already carrying what the .env,
# the command line and the defaults decided - nothing is parsed a second time.
die() {
    printf '%s\n' "$1" >&2
    exit 1
}

SRC=""
OUT=""
TEMPLATE_ARGS=()

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
            die "No document chosen - a menu needs a terminal. Name one instead: gmake pdf PDF_SRC=<file>"
        fi
        ;;
    esac
fi

# --- built where, with what ---------------------------------------------------

# PDF_OUT, or the source's name with .pdf. PDF_TEMPLATE, or template.tex when
# the project has one - pandoc's own template otherwise, and the line says so.
OUT=${PDF_OUT:-}
[ -n "$OUT" ] || OUT=${SRC%.md}.pdf

# An array, not a string: an empty variable between two other arguments would
# vanish into the word split - and shellcheck is right to refuse the unquoted
# one that kept the flag whole (measured by the CI's own shellcheck).
tpl=${PDF_TEMPLATE:-template.tex}
if [ -f "$tpl" ]; then
    TEMPLATE_ARGS=(--template="$tpl")
else
    printf '   no %s in this project: pandoc own template will be used.\n' "$tpl"
fi

# --- the build ----------------------------------------------------------------

# The command a document's own folder carries:
#   pandoc <src>.md --citeproc [--template=...] -o <out>.pdf --pdf-engine=xelatex
# --citeproc: the bibliography and the CSL style are read from the YAML header
# of the document itself. set -e is on: a build that fails stops here, before
# the tick line - a success line over a failed build is the one lie this script
# could tell.
echo "📄 Building $SRC -> $OUT (pandoc + xelatex)..."
pandoc "$SRC" --citeproc "${TEMPLATE_ARGS[@]}" -o "$OUT" --pdf-engine=xelatex
echo "✅ $OUT ($(du -h "$OUT" | cut -f1))"
