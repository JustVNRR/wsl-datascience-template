#!/usr/bin/env bash
# ==============================================================================
# THE GCP PACK - WHAT IT INSTALLS
# ==============================================================================
# `wsl.ps1 add_pack` copies this pack's folder into ~/.config/packs/gcp, then
# runs this script from inside it, as the instance's own user.
#
# The package and the repository address are root's business: one sudo, asked
# once, for a single root shell. Not several: `curl ... | sudo gpg` has no
# terminal on its input, so sudo could not have asked for a password there and
# would have failed whenever the ticket was not already open. One `sudo bash
# -c` is asked at a point where the keyboard is still free.
#
# The image carries no trace of Google - no signing key, no APT address. This
# script registers both, then installs the package. remove.sh undoes exactly
# that.

set -euo pipefail

echo "➕ Registering the Google APT repository..."
# set -o pipefail inside, because a pipe reports the exit code of its last
# command only: a curl that fails feeds gpg an empty input, and the failure
# must stop the install here rather than surface three steps later.
# DEBIAN_FRONTEND, so that a package reconfigured on the way never stops the
# install to ask a question.
#
# --batch --yes: gpg refuses to overwrite an existing output file without it,
# and the key file survives a removal that stopped halfway.
sudo bash -c 'set -eo pipefail
export DEBIAN_FRONTEND=noninteractive
mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
	| gpg --batch --yes --dearmor -o /etc/apt/keyrings/cloud.google.gpg
chmod go+r /etc/apt/keyrings/cloud.google.gpg
echo "deb [signed-by=/etc/apt/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
	> /etc/apt/sources.list.d/google-cloud-sdk.list
apt-get update
apt-get install -y --no-install-recommends google-cloud-cli'

echo "✅ Google Cloud CLI installed."
echo "   Next: gmake gcp_auth_cli (signs the CLI in to your Google account)."
