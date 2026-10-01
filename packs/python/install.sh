#!/usr/bin/env bash
# ==============================================================================
# THE PYTHON PACK - WHAT IT INSTALLS
# ==============================================================================
# `wsl.ps1 add_pack` copies this pack's folder into ~/.config/packs/python, then
# runs this script from inside it, as the instance's own user.
#
# Two halves: the compiler and the headers are root's business, asked once in a
# single sudo; Python and its tools are the user's - uv installs them under
# ~/.local, so removing them never asks for a password.
#
# The tools that create a project (copier, cruft, ccds) belong to the scaffold
# pack. This one installs what a project's environment needs: an interpreter,
# and ruff to lint it.

set -euo pipefail

# The PATH is built here, not inherited: the shell this script runs from
# carries WSL's Windows directories, and a name resolved through them can be a
# Windows program - the claude pack's installer uninstalled the Windows copy
# that way. The claude pack's clean_path, kept identical so the two read alike.
#
# ~/.local/bin is in it: uv warns on every tool when that directory is missing
# from the PATH, and the `uv` lines below must find what the line above
# installed.
clean_path=$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH=$clean_path

here=$(cd "$(dirname "$0")" && pwd)
packages=$(sed -n 's/^PACK_PACKAGES *:=[[:space:]]*//p' "$here/pack.conf")

if [ -z "$packages" ]; then
    echo "No PACK_PACKAGES found in $here/pack.conf" >&2
    exit 1
fi

echo "Installing the compilation tools (your password will be asked)..."
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
    echo "uv is already installed ($(uv --version)) - nothing to do."
else
    echo "Installing uv..."
    # UV_NO_MODIFY_PATH: left alone, uv's installer adds a line to the shell's
    # startup files; each pack declares its own PATH in its own zsh file.
    # pipefail makes the curl pipe safe: a failed curl would feed an empty
    # script, which exits 0.
    curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh
fi

echo "Installing Python 3 and ruff..."
uv python install 3
# --force: a shim left by an install that stopped halfway makes uv refuse to
# write ruff's, and a pack whose install can only be re-run after cleaning up
# by hand never finishes.
uv tool install --force ruff

echo "Python 3, uv and ruff are installed."
echo "   The commands are in the cheatsheet picker (fcheat)."
echo "   Next: fnew makes a project (it comes with the scaffold pack);"
echo "   add the gcp pack for the GCP targets."
