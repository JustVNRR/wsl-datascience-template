#!/usr/bin/env bash
# ==============================================================================
# THE PYTHON PACK - WHAT IT REMOVES
# ==============================================================================
# `wsl.ps1 remove_pack` runs this before deleting the pack's folder: what the
# install added leaves the machine, and only that.
#
# Two halves again. The apt packages go one at a time, and one that another
# installed pack still claims stays where it is: a pack does not own what it
# installs, it is one of the claimants (see docs/packs.md). A pack that is gone
# claims nothing.
#
# uv is the same question asked the same way, about something apt never saw. It
# is what a pack declares in PACK_OUTSIDE_APT - apt will never see it - and the
# pack that installed it asks before erasing anything. The scaffold pack names
# uv too, and every tool it runs goes through it: the first of the two to leave
# leaves uv where it is, the last one takes it away with everything it manages -
# the interpreter it downloaded, the tools' environments, its download cache.
# The whole tree goes together, because uv's shims point into it and half of it
# is worth nothing.
#
# Two things this never does: remove a library (a neighbour's program may depend
# on it, and apt would take that program along), and autoremove (the shared
# libraries these tools pulled in are not ours to judge).

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
packages=$(sed -n 's/^PACK_PACKAGES *:=[[:space:]]*//p' "$here/pack.conf")

if [ -z "$packages" ]; then
    echo "❌ No PACK_PACKAGES found in $here/pack.conf" >&2
    exit 1
fi

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

echo "➖ Removing the compilation tools..."
for package in $packages; do
    if claimed_elsewhere "$package"; then
        echo "⏭️  $package: another installed pack claims it - left in place."
        continue
    fi
    # A failure here is not the end of the removal: what apt cannot take back,
    # it says so about, and the script goes on to what it can (uv, below, which
    # is not apt's business at all). Measured: with no package lists,
    # `apt-get remove` answers "Unable to locate package" even for a package
    # that is installed, and a `set -e` script would stop there and leave the
    # rest of the pack on the machine.
    if ! sudo apt-get remove -y "$package"; then
        echo "⚠️  $package: apt could not remove it — left where it is."
        echo "   (apt needs its package lists: run 'sudo apt-get update' inside the"
        echo "   instance, then remove the pack again.)"
    fi
done

# ruff is this pack's, and it goes back whether or not uv stays: it is the one
# thing here that another pack's uv has nothing to do with. Both halves matter.
# The environment under uv's tree is where ruff lives, and the shim in
# ~/.local/bin is where the next install trips: uv refuses to write an
# executable that is already there ("Executable already exists: ruff"), so a
# shim left behind is an install that fails every time it is run again - and
# worse, a shim whose target has just been removed is a command that answers
# "No such file or directory" to whoever types it.
echo "➖ Removing ruff..."
rm -f "$HOME/.local/bin/ruff"
rm -rf "$HOME/.local/share/uv/tools/ruff"

if claimed_elsewhere uv; then
    echo "⏭️  uv: another installed pack claims it — left in place, with what it manages."
else
    echo "➖ Removing uv and what it installed..."
    # By name, and not by asking uv itself: `uv tool uninstall` and `uv python
    # uninstall` would be the tidy way, but they live on the very binary being
    # removed, and a removal has to work on a machine where the install stopped
    # halfway. Everything uv wrote is in two places - ~/.local/bin for the shims,
    # ~/.local/share/uv for the Python builds and the tools' environments - plus
    # its download cache. Every path is spelled from $HOME, so none can be empty
    # when `rm` reads it, and `rm -f` never fails on one that is already gone.
    #
    # The Python shims are named after their version (`python3.14`), and the pack
    # never chose that version: it asks uv for `3`, whatever that is today. Hence
    # the glob where the tools get a name. nullglob, so a machine with no managed
    # Python left hands `rm` nothing at all rather than the pattern.
    shopt -s nullglob
    rm -rf "$HOME/.local/bin/uv" \
           "$HOME/.local/bin/uvx" \
           "$HOME"/.local/bin/python3.* \
           "$HOME/.local/bin/copier" \
           "$HOME/.local/bin/cruft" \
           "$HOME/.local/bin/ruff" \
           "$HOME/.local/bin/cookiecutter" \
           "$HOME/.local/bin/ccds" \
           "$HOME/.local/share/uv" \
           "$HOME/.cache/uv"
fi

echo "✅ Python 3 and its tools are gone."
echo "   What the pack wrote in ~/.local went with it; your projects are where they were."
