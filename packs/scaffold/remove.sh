#!/usr/bin/env bash
# ==============================================================================
# THE SCAFFOLD PACK - WHAT IT REMOVES
# ==============================================================================
# `wsl.ps1 remove_pack` runs this before deleting the pack's folder: what the
# install added leaves the machine, and only that.
#
# One thing to take back - uv - and one thing never to touch: ~/projects. The
# projects in there are yours, not the pack's: it wrote none of them, and it
# does not create the folder either (that comes from the image, and outlives
# every pack).
#
# uv is the python pack's as well: it uses it for the environments of the
# projects this one scaffolds. So the question is asked before anything is
# erased - the same one PACK_PACKAGES answers for apt's packages - and a pack
# does not decide alone about a tool another one is still using. The last pack
# that declares it takes it away, with the interpreter it downloaded and its
# cache.

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)

# Is this name declared by another pack that is still installed?
#
# A claim is a declaration, not a mention: these files talk about what they
# install, and a comment that says "uv" claims nothing. So the name is read off
# the two declaration lines - PACK_PACKAGES for what apt installs,
# PACK_OUTSIDE_APT for what apt never sees - and off install.sh as well, in one
# piece, for a pack written before PACK_PACKAGES existed.
claimed_elsewhere() {
    local other value word
    for other in "$HOME"/.config/packs/*/; do
        if [ "${other%/}" = "$here" ]; then
            continue
        fi
        value=$(sed -nE 's/^PACK_(PACKAGES|OUTSIDE_APT) *:=[[:space:]]*//p' "$other/pack.conf" 2>/dev/null)
        for word in $value; do
            if [ "$word" = "$1" ]; then
                return 0
            fi
        done
        grep -q -- "$1" "$other/install.sh" 2>/dev/null && return 0
    done
    return 1
}

if claimed_elsewhere uv; then
    echo "⏭️  uv: another installed pack claims it — left in place, with what it manages."
else
    echo "➖ Removing uv and what it manages..."
    # Everything uv wrote is in two places, its shims in ~/.local/bin and its
    # Python builds and tools under ~/.local/share/uv, plus its download cache.
    # Every path is spelled from $HOME, so none can be empty when `rm` reads it,
    # and `rm -f` never fails on one that is already gone.
    rm -rf "$HOME/.local/bin/uv" \
           "$HOME/.local/bin/uvx" \
           "$HOME"/.local/bin/python3.* \
           "$HOME/.local/share/uv" \
           "$HOME/.cache/uv"
fi

echo "✅ The scaffolding is gone."
echo "   ~/projects was left alone — the projects in it are yours."
