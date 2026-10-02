#!/usr/bin/env bash
# ==============================================================================
# THE GCP PACK - WHAT IT REMOVES
# ==============================================================================
# `wsl.ps1 remove_pack` runs this before deleting the pack's folder: what the
# install added to the system leaves it - the CLI, the signing key, the APT
# address - and nothing else.
#
# The logins in ~/.config/gcloud are the user's, not the pack's: they stay.

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)

echo "Removing the Google APT repository..."
sudo bash "$here/remove_root.sh"

echo "Google Cloud CLI removed."
echo "   Your logins (~/.config/gcloud) were left alone - delete that directory to forget them."
