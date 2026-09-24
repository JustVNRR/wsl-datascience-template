#!/usr/bin/env bash
# ==============================================================================
# THE VISION PACK - WHAT IT INSTALLS
# ==============================================================================
# `wsl.ps1 add_pack` copies this pack's folder into ~/.config/packs/vision, then
# runs this script from inside it, as the instance's own user.
#
# Everything here belongs to root, so it takes one sudo, asked once. What it
# installs is read from pack.conf - the same line remove.sh reads, so the two
# cannot drift apart, and a neighbour can ask who claims what.

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
packages=$(sed -n 's/^PACK_PACKAGES *:=[[:space:]]*//p' "$here/pack.conf")

if [ -z "$packages" ]; then
    echo "❌ No PACK_PACKAGES found in $here/pack.conf" >&2
    exit 1
fi

echo "➕ Installing the vision and OCR tools (your password will be asked)..."
# DEBIAN_FRONTEND, so that a package reconfigured on the way never stops the
# install to ask a question. set -o pipefail is not needed here - nothing is
# piped - but the install is one command, so a failure stops at it.
sudo bash -c "set -eo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends $packages"

echo "✅ ffmpeg, ImageMagick and Tesseract are installed."
echo "   Their commands are in the cheatsheet picker (fcheat)."
