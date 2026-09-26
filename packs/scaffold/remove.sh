#!/usr/bin/env bash
# ==============================================================================
# THE SCAFFOLD PACK - WHAT IT REMOVES
# ==============================================================================
# `wsl.ps1 remove_pack` runs this before deleting the pack's folder: what the
# install added leaves the machine, and only that.
#
# Nothing here is removed by hand. The projects this pack scaffolds are yours,
# in ~/projects - no pack touches them, and this one wrote none of them. The one
# tool it installs, uv, is used by another installed pack as well, and taking a
# shared tool away is not this pack's decision to make alone.

set -euo pipefail

echo "✅ Nothing of this pack's is removed by hand."
echo "   ~/projects was left alone — the projects in it are yours."
echo "   uv stays: the python pack uses it for its projects' environments."
