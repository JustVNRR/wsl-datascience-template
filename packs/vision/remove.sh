#!/usr/bin/env bash
# ==============================================================================
# THE VISION PACK - WHAT IT REMOVES
# ==============================================================================
# `wsl.ps1 remove_pack` runs this before deleting the pack's folder: what the
# install added to the system leaves it, and only that.
#
# One package at a time, because a package another installed pack still claims
# must stay where it is: a pack does not own what it installs, it is one of the
# claimants. The claim is read from every pack's declaration - pack.conf, and
# install.sh as well, for a pack written before PACK_PACKAGES existed. A pack
# that is gone claims nothing: the last one to want a package takes it away.
#
# Two things this never does: remove a library (a neighbour's program may
# depend on it, and apt would take that program along), and autoremove (the
# shared libraries these tools pulled in are not ours to judge).

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

echo "➖ Removing the vision and OCR tools..."
for package in $packages; do
    if claimed_elsewhere "$package"; then
        echo "⏭️  $package: another installed pack claims it - left in place."
        continue
    fi
    sudo apt-get remove -y "$package"
done

echo "✅ ffmpeg, ImageMagick and Tesseract are gone."
echo "   Your own files were left alone - the pack wrote none of them."
