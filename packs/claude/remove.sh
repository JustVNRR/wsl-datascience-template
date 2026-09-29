#!/usr/bin/env bash
# ==============================================================================
# THE CLAUDE PACK - WHAT IT REMOVES
# ==============================================================================
# `wsl.ps1 remove_pack` runs this before deleting the pack's folder: what the
# install added leaves the machine, and only that.
#
# Two things to take back, and they are the whole weight: the launcher and the
# versions behind it. One thing is never touched: ~/.claude, which holds the
# settings, the credentials, the prompt history and the sessions. The pack wrote
# none of them - the CLI did, at your first run - so they stay, exactly as
# ~/.mozilla stays when the web pack leaves.

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)

# Is this name declared by another pack that is still installed?
#
# A claim is a declaration, not a mention: these files talk about what they
# install, and a comment that says "claude" claims nothing. So the name is read
# off the two declaration lines - PACK_PACKAGES for what apt installs,
# PACK_OUTSIDE_APT for what apt never sees - and off install.sh as well, in one
# piece, for a pack written before PACK_PACKAGES existed.
claimed_elsewhere() {
    local other value word
    for other in "$HOME"/.config/packs/*/; do
        if [ "${other%/}" = "$here" ]; then
            continue
        fi
        value=$(sed -nE 's/^PACK_(PACKAGES|OUTSIDE_APT) *:=[[:space:]]*//p' "$other/pack.conf" 2>/dev/null)
        for word in $value; do
            if [ "$word" = "$1" ]; then
                return 0
            fi
        done
        grep -q -- "$1" "$other/install.sh" 2>/dev/null && return 0
    done
    return 1
}

if claimed_elsewhere claude; then
    echo "claude: another installed pack claims it - left in place, with the versions it keeps."
else
    echo "Removing Claude Code and the versions it keeps..."
    # Every path is spelled from $HOME, so none can be empty when `rm` reads it,
    # and `rm -f` never fails on one that is already gone. The launcher may be a
    # symlink (the ordinary case) or a launcher file the CLI wrote for itself;
    # `rm -f` takes either, and takes nothing else.
    rm -f "$HOME/.local/bin/claude"
    rm -rf "$HOME/.local/share/claude"
fi

echo "Claude Code is gone."
echo "   ~/.claude was left alone: its settings, its history and its login are yours."

# Everything printed above is plain ASCII, like install.sh and for the same
# reason: this text travels through wsl.exe to the Windows console, which reads
# it in its own code page.
