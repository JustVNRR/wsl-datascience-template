#!/usr/bin/env bash
# ==============================================================================
# THE DEV PACK - WHAT IT INSTALLS
# ==============================================================================
# `wsl.ps1 add_pack` copies this pack's folder into ~/.config/packs/dev, then
# runs this script from inside it, as the instance's own user.
#
# It installs nothing, and that is the pack: what it brings is gmake modules -
# text, already in its folder and loaded from there. The two tools its targets
# drive are on the machine before any pack arrives: docker comes from Docker
# Desktop, gh from the image.
#
# The file exists so that a pack stays a pack - same folder, same two scripts,
# same lifecycle as the others. It says what it did, which here is nothing.

set -euo pipefail

echo "✅ Nothing to install: this pack is gmake modules, and its two tools"
echo "   (docker, gh) are already on this machine."
echo "   Its targets appear in:  gmake help"
