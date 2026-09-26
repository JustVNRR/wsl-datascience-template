#!/usr/bin/env bash
# ==============================================================================
# THE SCAFFOLD PACK - WHAT IT INSTALLS
# ==============================================================================
# `wsl.ps1 add_pack` copies this pack's folder into ~/.config/packs/scaffold,
# then runs this script from inside it, as the instance's own user.
#
# One tool: uv, about 67 MB under ~/.local - the same binary the python pack
# uses for its projects, and it may well be there already. The three tools the
# targets drive (copier, cruft, ccds) are NOT installed: `uvx --from ...` takes
# each one from uv's cache the first time it runs (measured: 27 s and about
# 40 MB for the first, 3 s and about 20 MB for each one after), and a command
# that is never used costs nothing.

set -euo pipefail

# This runs from a shell that has not read the zsh configuration, so ~/.local/bin
# is not on its PATH: the check below and uv's own installer both need it there.
export PATH="$HOME/.local/bin:$PATH"

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

echo "✅ The scaffolding is ready."
echo "   The template tools are fetched on the first fnew, one at a time."
echo "   Next: cd projects, then type fnew."
