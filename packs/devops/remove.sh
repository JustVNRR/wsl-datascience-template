#!/usr/bin/env bash
# ==============================================================================
# THE DEVOPS PACK - WHAT IT REMOVES
# ==============================================================================
# `wsl.ps1 remove_pack` runs this before deleting the pack's folder: what the
# install added to the system leaves it, and only that.
#
# It has nothing to take back - it installed nothing - and one thing it must
# never touch: ~/projects. The projects in there are yours, not the pack's. It
# wrote none of them, it does not delete them, and it does not create the folder
# either: ~/projects comes from the image, and it outlives every pack.

set -euo pipefail

echo "✅ Nothing to remove: this pack installed nothing."
echo "   ~/projects and the .env files inside it were left alone - they are yours."
