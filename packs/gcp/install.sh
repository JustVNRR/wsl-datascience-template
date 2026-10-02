#!/usr/bin/env bash
# ==============================================================================
# THE GCP PACK - WHAT IT INSTALLS
# ==============================================================================
# `wsl.ps1 add_pack` copies this pack's folder into ~/.config/packs/gcp, then
# runs this script from inside it, as the instance's own user.
#
# The root half - the repository, the key, the package - is in install_root.sh,
# beside this file: one sudo, asked once.
#
# The image carries no trace of Google - no signing key, no APT address. This
# script registers both, then installs the package; remove.sh undoes exactly
# that.

set -euo pipefail

# The messages: the shared library replaces this fallback when the image
# carries it; an instance built before it prints a plain sentence.
success() { printf '%s\n' "$*"; }
if [ -r "$HOME/.config/zsh/lib/message.sh" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.config/zsh/lib/message.sh" || true
fi

here=$(cd "$(dirname "$0")" && pwd)

sudo bash "$here/install_root.sh"

success "Google Cloud CLI installed."