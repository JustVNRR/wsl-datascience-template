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
#   - Python and the tools belong to the user who runs this. uv installs and
#     manages them under ~/.local, so removing them never asks for a password.

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

echo "➕ Installing Python 3 and the scaffolding tools..."
# UV_NO_MODIFY_PATH: left alone, uv's installer adds a line to the shell's
# startup files - ~/.zshenv among them - to put itself on the PATH. The pack
# declares its own PATH in its own zsh file, so a removal has nothing to undo in
# yours.
# pipefail is on from the top of this script, and it is what makes the pipe safe:
# a curl that fails would feed the installer an empty script, which exits 0, and
# the failure would surface one step later, on a missing `uv`.
curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh
uv python install 3
uv tool install copier
uv tool install cruft
uv tool install ruff
uv tool install cookiecutter
uv tool install cookiecutter-data-science

echo "✅ Python 3 and its tools are installed."
echo "   The commands are in the cheatsheet picker (fcheat)."
echo "   Next: fnew scaffolds a project; add the gcp pack for the MLOps targets."
