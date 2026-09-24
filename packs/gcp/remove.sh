#!/usr/bin/env bash
# ==============================================================================
# THE GCP PACK - WHAT IT REMOVES
# ==============================================================================
# `wsl.ps1 remove_pack` runs this before deleting the pack's folder: what the
# install added to the system leaves it - the CLI, the signing key, the APT
# address - and nothing else.
#
# The logins in ~/.config/gcloud are the user's, not the pack's: they stay,
# exactly as they did when this was a make target.

set -euo pipefail

echo "➖ Removing the Google APT repository..."
sudo bash -c 'set -eo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get remove -y google-cloud-cli
rm -f /etc/apt/keyrings/cloud.google.gpg /etc/apt/sources.list.d/google-cloud-sdk.list'

echo "✅ Google Cloud CLI removed."
echo "   Your logins (~/.config/gcloud) were left alone - delete that directory to forget them."
