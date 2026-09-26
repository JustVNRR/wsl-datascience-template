#!/usr/bin/env bash
# ==============================================================================
# THE PYTHON PACK - WHAT IT REMOVES
# ==============================================================================
# `wsl.ps1 remove_pack` runs this before deleting the pack's folder: what the
# install added leaves the machine, and only that.
#
# Two halves again. The apt packages go one at a time, and one that another
# installed pack still claims stays where it is: a pack does not own what it
# installs, it is one of the claimants (see docs/packs.md). The claim is read
# from every pack's declaration - pack.conf, and install.sh as well, for a pack
# written before PACK_PACKAGES existed. A pack that is gone claims nothing.
#
# What apt never saw - uv, the Pythons it downloaded, the tools it built, its
# cache - is named here by hand. `remove_pack`'s dependency cleanup cannot see
# it: that one asks apt and ldd what no installed package needs any more, and uv
# is not a package. Nothing else would ever take these away.
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

# Is this package claimed by another pack that is still installed?
claimed_elsewhere() {
    grep -rl --include=pack.conf --include=install.sh -- "$1" "$HOME/.config/packs" 2>/dev/null |
        grep -qv "^${here}/"
}

echo "➖ Removing the compilation tools..."
for package in $packages; do
    if claimed_elsewhere "$package"; then
        echo "⏭️  $package: another installed pack claims it - left in place."
        continue
    fi
    sudo apt-get remove -y "$package"
done

echo "➖ Removing uv and what it installed..."
# By name, and not by asking uv itself: `uv tool uninstall` and `uv python
# uninstall` would be the tidy way, but they live on the very binary being
# removed, and a removal has to work on a machine where the install stopped
# halfway. Everything uv wrote is in two places - ~/.local/bin for the shims,
# ~/.local/share/uv for the Python builds and the tools' environments - plus its
# download cache. Every path is spelled from $HOME, so none can be empty when
# `rm` reads it, and `rm -f` never fails on one that is already gone.
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

echo "✅ Python 3 and its tools are gone."
echo "   What the pack wrote in ~/.local went with it; your projects are where they were."
