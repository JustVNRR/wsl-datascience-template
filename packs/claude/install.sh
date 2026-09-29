#!/usr/bin/env bash
# ==============================================================================
# THE CLAUDE PACK - WHAT IT INSTALLS
# ==============================================================================
# `wsl.ps1 add_pack` copies this pack's folder into ~/.config/packs/claude, then
# runs this script from inside it, as the instance's own user.
#
# One tool, and it asks for no password: Anthropic's own installer unpacks a
# single binary under ~/.local - the launcher at ~/.local/bin/claude, the
# versions it keeps at ~/.local/share/claude/versions/<version>. Measured at
# 232 MiB for one version, and several minutes of download on a slow link, which
# is why the script says what it is about to do before doing it.

set -euo pipefail

# This runs from a shell that has not read the zsh configuration, so ~/.local/bin
# is not on its PATH: the check below needs it there.
export PATH="$HOME/.local/bin:$PATH"

# The pack's own launcher, at the path this pack installs it to - never whatever
# `claude` the PATH happens to resolve to. WSL appends the Windows directories
# to the PATH, so a Claude Code installed on Windows (npm, or its own installer)
# is found from inside the instance: asking the PATH would answer "already
# installed" about a program that runs on the other side of the wall, and this
# script would install nothing at all. Measured, on a real instance.
launcher=$HOME/.local/bin/claude

if [ -x "$launcher" ]; then
    echo "✅ Claude Code is already installed ($("$launcher" --version)) — nothing to do."
else
    # Named, not removed: the person will type `claude` and see it work, and the
    # one line here is what explains why this pack installs its own anyway.
    foreign=$(command -v claude 2>/dev/null || true)
    if [ -n "$foreign" ]; then
        echo "ℹ️  A 'claude' from outside this instance is on the PATH ($foreign)."
        echo "    It runs on Windows, not here; this pack installs its own."
    fi
    echo "➕ Installing Claude Code from Anthropic's own script (about 230 MB, a few minutes)..."
    # No sudo, and the installer refuses it: everything lands under $HOME, and
    # under sudo that $HOME is root's, where the launcher would not be found by
    # anyone. Nothing here needs root, which is the other half of why this pack
    # declares PACK_OUTSIDE_APT instead of PACK_PACKAGES.
    #
    # pipefail is on from the top of this script, and it is what makes the pipe
    # safe: a curl that fails would feed the installer an empty script, which
    # exits 0, and the failure would surface one step later, on a missing
    # `claude`.
    #
    # The installer ends by *printing* a note - "~/.local/bin is not in your
    # PATH, run: echo ... >> your shell config file" - and nothing is done about
    # it here on purpose: the socle already exports that directory
    # (zsh/exports.zsh), so the note is already answered, and a pack that writes
    # into your files has something to undo the day it leaves. There is no
    # opt-out variable to set, unlike uv's installer, because there is nothing
    # to opt out of.
    curl -fsSL https://claude.ai/install.sh | bash
fi

echo "✅ Claude Code is ready."
echo "   Next: gmake claude_status, and the first 'claude' asks you to log in."
