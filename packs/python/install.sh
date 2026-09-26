#!/usr/bin/env bash
# ==============================================================================
# THE PYTHON PACK - WHAT IT INSTALLS
# ==============================================================================
# `wsl.ps1 add_pack` copies this pack's folder into ~/.config/packs/python, then
# runs this script from inside it, as the instance's own user.
#
# Two halves, one script:
#   - the compiler and the headers are root's business, asked for once, in a
#     single sudo - one `sudo bash -c` is asked at a point where the keyboard is
#     still free, whereas several small suds would each need the ticket;
#   - Python and its tools belong to the user who runs this. uv installs and
#     manages them under ~/.local, so removing them never asks for a password.
#
# The tools that create a project - copier, cruft, ccds - are not installed
# here: they belong to the scaffold pack, which takes each one from uv's cache
# the day it is first used. What this script installs is what a project's
# environment needs: an interpreter, and ruff to lint it.

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
packages=$(sed -n 's/^PACK_PACKAGES *:=[[:space:]]*//p' "$here/pack.conf")

if [ -z "$packages" ]; then
    echo "❌ No PACK_PACKAGES found in $here/pack.conf" >&2
    exit 1
fi

# This runs from a shell that has not read the zsh configuration, so
# ~/.local/bin is not on its PATH: uv would warn on every tool it installs, and
# the `uv` lines below would not find the binary the line above just installed.
export PATH="$HOME/.local/bin:$PATH"

echo "➕ Installing the compilation tools (your password will be asked)..."
# DEBIAN_FRONTEND, so that a package reconfigured on the way (tzdata and its
# continent question) never stops the install to ask something.
sudo bash -c "set -eo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends $packages"

# uv may already be there: this pack requires the scaffold pack, which installs
# it and comes first. Asking the machine rather than installing a second time
# keeps the download to one.
if command -v uv >/dev/null 2>&1; then
    echo "✅ uv is already installed ($(uv --version)) — nothing to do."
else
    echo "➕ Installing uv..."
    # UV_NO_MODIFY_PATH: left alone, uv's installer adds a line to the shell's
    # startup files - ~/.zshenv among them - to put itself on the PATH. Each pack
    # that needs it declares its own PATH in its own zsh file, so a removal has
    # nothing to undo in yours.
    # pipefail is on from the top of this script, and it is what makes the pipe
    # safe: a curl that fails would feed the installer an empty script, which
    # exits 0, and the failure would surface one step later, on a missing `uv`.
    curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh
fi

echo "➕ Installing Python 3 and ruff..."
uv python install 3
# --force: a shim left by an install that stopped halfway makes uv refuse to
# write ruff's ("Executable already exists: ruff"), and a pack whose install can
# only be re-run after cleaning up by hand is a pack that never finishes - the
# message above the prompt says "run this again to finish", and it has to be
# true.
uv tool install --force ruff

echo "✅ Python 3, uv and ruff are installed."
echo "   The commands are in the cheatsheet picker (fcheat)."
echo "   Next: fnew makes a project (it comes with the scaffold pack);"
echo "   add the gcp pack for the MLOps targets."
