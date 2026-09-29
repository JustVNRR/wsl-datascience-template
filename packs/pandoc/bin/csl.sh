#!/usr/bin/env bash
# ==============================================================================
# THE PANDOC PACK - `csl_from_catalog`: A CITATION STYLE, FROM THE OFFICIAL CATALOG
# ==============================================================================
# A .csl (Citation Style Language) is the file that tells pandoc how citations
# are written and how the bibliography is ordered: numbers or author-year,
# superscript or not, the punctuation, the order. The document names its own
# in its YAML header (`csl: vancouver-superscript.csl`) and the file travels
# beside it. A style belongs to the document, not to the tool - which is why
# the pack ships none - and this target fetches one from the official catalog
# (the Citation Style Language project, the ten thousand styles Zotero
# offers) into the project.
#
# Which one: STYLE names it - `gmake csl_from_catalog STYLE=ieee` - and the file comes
# straight from the catalog's raw storage: no list, nothing to choose, and the
# only path that works without a terminal. Unnamed, a menu asks: the list is
# one call to GitHub's API, fzf filters it (a few letters), and the chosen
# file is downloaded from the same raw storage.
#
# This runs inside the instance, where the network is WSL's; a machine without
# it gets the two lines below, not a hang.
set -euo pipefail

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

raw=https://raw.githubusercontent.com/citation-style-language/styles/master

STYLE=${STYLE:-}

if [ -z "$STYLE" ]; then
    # The catalog's own tree, one call. `dependent` styles are left out on
    # purpose: they are pointers to another style (a journal's flavour of one),
    # they carry no rules of their own, and the target is about rules. What
    # comes back is every independent style, one name per line.
    json=$(curl -fsSL 'https://api.github.com/repos/citation-style-language/styles/git/trees/master?recursive=1') ||
        die "the catalog could not be read - is there a network? Name a style instead: gmake csl_from_catalog STYLE=<name>"
    catalog=$(printf '%s\n' "$json" |
        sed -n 's/.*"path": *"\([^"]*\)\.csl".*/\1/p' |
        grep -v / | sort -u || true)
    [ -n "$catalog" ] || die "the catalog came back empty - name a style instead: gmake csl_from_catalog STYLE=<name>"

    # fzf, like every other picker of this shell. A menu needs a terminal;
    # STYLE is what a script calls.
    if choice=$(printf '%s\n' "$catalog" | fzf --prompt="style > " --info=inline --layout=reverse); then
        [ -n "$choice" ] || die "Nothing chosen."
        STYLE=$choice
    else
        status=$?
        # fzf exits 130 on Escape or Ctrl-C: a decision, not a failure.
        if [ "$status" -eq 130 ]; then
            printf 'Nothing chosen.\n'
            exit 0
        fi
        die "No style chosen - a menu needs a terminal. Name one instead: gmake csl_from_catalog STYLE=<name>"
    fi
fi

# The style, beside the document that names it. One that is already there is
# left alone: it may be a version someone edited, and this target fetches.
out=$STYLE.csl
if [ -f "$out" ]; then
    echo "$out is already here - left as it is."
    exit 0
fi

curl -fsSL -o "$out" "$raw/$STYLE.csl" ||
    die "$STYLE: not in the catalog - the name is the one zotero.org/styles shows (vancouver, ieee, apa...), or there is no network."

echo "✅ $out"
echo "   The document names it in its YAML header:  csl: $STYLE.csl"
